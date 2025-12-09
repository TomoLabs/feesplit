// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice On-chain Splitwise: groups, expenses, manual repayment, and hook-driven automatic repayment.
/// - Equal split only (can be extended).
/// - Tracks debts as owed[debtor][creditor].
/// - autoRepay(...) is callable only by the configured hook and will:
///    1) accept tokens already transferred to this contract by the caller (hook),
///    2) reduce outstanding debts owed to `payer` proportionally,
///    3) forward the tokens to the `payer`.
/// NOTE: This contract expects the hook to transfer tokens to this contract before / during the call
/// (e.g. the hook can do IERC20(token).safeTransfer(address(splitwise), amount); then call autoRepay).
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract Splitwise is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Groups
    struct Group {
        address[] members;
        bool exists;
    }

    // events
    event GroupCreated(uint256 indexed groupId, address[] members);
    event ExpenseAdded(uint256 indexed groupId, address indexed payer, uint256 totalAmount, address token);
    event ManualRepayment(address indexed debtor, address indexed creditor, address token, uint256 amount);
    event AutoRepayment(address indexed payer, address token, uint256 amount);
    event HookSet(address indexed hook);

    // group id counter
    uint256 public nextGroupId;

    // mapping groupId -> Group
    mapping(uint256 => Group) public groups;

    // owed[debtor][creditor] = amount debtor owes creditor (in token decimals units)
    mapping(address => mapping(address => uint256)) public owed;

    // For each creditor (payer) we track a list of debtors who currently owe >0 to them.
    mapping(address => address[]) internal creditorDebtors;
    // debtor -> creditor -> index+1 in creditorDebtors[creditor] (0 means not present)
    mapping(address => mapping(address => uint256)) internal debtorIndexInCreditorList;

    // Hook address (set by owner)
    address public hook;

    constructor() Ownable(msg.sender) {
    nextGroupId = 1;
}


    /// @notice Owner sets the authorized hook contract which may call autoRepay.
    function setHook(address _hook) external onlyOwner {
        require(hook == address(0), "hook already set");
        require(_hook != address(0), "hook zero");
        hook = _hook;
        emit HookSet(_hook);
    }

    /// -----------------------------------------------------------------------
    /// Group & Expense management
    /// -----------------------------------------------------------------------
    /// @notice Create a group of participants. members must be unique and length >= 2
    function createGroup(address[] calldata members) external returns (uint256) {
        require(members.length >= 2, "need >=2");
        // basic duplication check (cheap)
        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0), "zero member");
            for (uint256 j = i + 1; j < members.length; j++) {
                require(members[i] != members[j], "duplicate member");
            }
        }

        uint256 gid = nextGroupId++;
        groups[gid] = Group({members: members, exists: true});
        emit GroupCreated(gid, members);
        return gid;
    }

    /// @notice Add an expense where `payer` paid `totalAmount` for the group. Splits equally among group members.
    /// Each non-payer member will owe payer: share = totalAmount / members.length
    function addExpense(uint256 groupId, address token, uint256 totalAmount, address payer) external {
        require(groups[groupId].exists, "group not found");
        Group storage g = groups[groupId];
        require(totalAmount > 0, "amount zero");
        require(isMember(g.members, payer), "payer not member");

        uint256 memberCount = g.members.length;
        uint256 share = totalAmount / memberCount; // integer division; payer's own share remains counted in total
        // for fairness you may want to track remainder separately; here we assign integer shares

        for (uint256 i = 0; i < memberCount; i++) {
            address member = g.members[i];
            if (member == payer) {
                continue; // payer doesn't owe themself
            }
            // increase debt: member owes payer 'share'
            _increaseDebt(member, payer, share);
        }

        emit ExpenseAdded(groupId, payer, totalAmount, token);
    }

    /// -----------------------------------------------------------------------
    /// Debt bookkeeping helpers
    /// -----------------------------------------------------------------------
    function _increaseDebt(address debtor, address creditor, uint256 amount) internal {
        if (amount == 0) return;
        if (owed[debtor][creditor] == 0) {
            // add to creditor's debtor list
            creditorDebtors[creditor].push(debtor);
            debtorIndexInCreditorList[debtor][creditor] = creditorDebtors[creditor].length; // index+1
        }
        owed[debtor][creditor] += amount;
    }

    function _decreaseDebt(address debtor, address creditor, uint256 amount) internal {
        uint256 cur = owed[debtor][creditor];
        if (amount >= cur) {
            // remove
            owed[debtor][creditor] = 0;
            _removeDebtorFromCreditorList(creditor, debtor);
        } else {
            owed[debtor][creditor] = cur - amount;
        }
    }

    function _removeDebtorFromCreditorList(address creditor, address debtor) internal {
        uint256 idxp1 = debtorIndexInCreditorList[debtor][creditor];
        if (idxp1 == 0) return; // not present
        uint256 idx = idxp1 - 1;
        address[] storage list = creditorDebtors[creditor];
        uint256 last = list.length - 1;
        if (idx != last) {
            address swapped = list[last];
            list[idx] = swapped;
            debtorIndexInCreditorList[swapped][creditor] = idx + 1;
        }
        list.pop();
        debtorIndexInCreditorList[debtor][creditor] = 0;
    }

    function isMember(address[] storage members, address who) internal view returns (bool) {
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == who) return true;
        }
        return false;
    }

    /// -----------------------------------------------------------------------
    /// Manual repayment by debtor (transfers tokens to creditor)
    /// -----------------------------------------------------------------------
    /// @notice Debtor calls this to repay `amount` of `token` to `creditor`. The contract will pull tokens from debtor and forward to creditor.
    function repay(address creditor, address token, uint256 amount) external nonReentrant {
        address debtor = msg.sender;
        require(amount > 0, "amount zero");
        uint256 cur = owed[debtor][creditor];
        require(cur > 0, "no debt");
        uint256 pay = amount > cur ? cur : amount;

        // pull tokens from debtor, forward to creditor
        IERC20(token).safeTransferFrom(debtor, creditor, pay);

        // bookkeeping
        _decreaseDebt(debtor, creditor, pay);

        emit ManualRepayment(debtor, creditor, token, pay);
    }

    /// -----------------------------------------------------------------------
    /// Auto repayment called by hook after sending tokens to this contract
    /// -----------------------------------------------------------------------
    /// @notice Called by authorized hook when tokens were forwarded to this contract for `payer`. This function:
    ///    - reads `amount` of `token` already held by this contract (assumed transferred by caller),
    ///    - reduces debts owed to `payer` proportionally among their debtors,
    ///    - forwards the incoming `amount` to `payer`.
    ///
    /// Security: only the configured hook address can call this.
    function autoRepay(address payer, address token, uint256 amount) external nonReentrant {
        require(msg.sender == hook, "only hook");
        require(amount > 0, "amount zero");

        // confirm contract actually holds at least `amount` of token (hook should transfer before calling)
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal >= amount, "insufficient token in contract");

        // total outstanding owed to payer
        uint256 totalOwed = 0;
        address[] storage debtors = creditorDebtors[payer];
        for (uint256 i = 0; i < debtors.length; i++) {
            totalOwed += owed[debtors[i]][payer];
        }

        if (totalOwed == 0) {
            // nothing owed; forward whole amount to payer
            IERC20(token).safeTransfer(payer, amount);
            emit AutoRepayment(payer, token, amount);
            return;
        }

        // Distribute amount proportionally to each debtor's owed amount.
        // To avoid rounding leaving dust, we'll allocate proportional shares and send remainder to payer.
        uint256 distributed = 0;
        for (uint256 i = 0; i < debtors.length; i++) {
            address debtor = debtors[i];
            uint256 debtorOwes = owed[debtor][payer];
            if (debtorOwes == 0) continue;
            // share = amount * debtorOwes / totalOwed
            uint256 share = (amount * debtorOwes) / totalOwed;
            if (share == 0) continue;
            // reduce debt by share
            _decreaseDebt(debtor, payer, share);
            distributed += share;
        }

        // send distributed shares to payer (we can send the full amount; payer receives the full amount, but we reduced debts by distributed)
        // note: any dust (amount - distributed) we still forward to payer as extra amount
        IERC20(token).safeTransfer(payer, amount);

        emit AutoRepayment(payer, token, amount);
    }

    /// -----------------------------------------------------------------------
    /// View helpers
    /// -----------------------------------------------------------------------
    function getGroupMembers(uint256 groupId) external view returns (address[] memory) {
        return groups[groupId].members;
    }

    function getDebtorsForCreditor(address creditor) external view returns (address[] memory) {
        return creditorDebtors[creditor];
    }

    function getOwed(address debtor, address creditor) external view returns (uint256) {
        return owed[debtor][creditor];
    }
}
