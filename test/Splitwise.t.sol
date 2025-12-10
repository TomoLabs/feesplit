// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/splitwise.sol";

// Mock ERC20 contract for testing token transfers
contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "no balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "no balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract SplitwiseTest is Test {
    Splitwise public splitwise;
    MockERC20 public token;

    // Defined addresses for testing
    address public constant ALICE = address(0xA1);
    address public constant BOB = address(0xB2);
    address public constant PAYER = address(0xC3);

    function setUp() public {
        splitwise = new Splitwise();
        token = new MockERC20();

        // Label addresses for clarity in traces
        vm.label(ALICE, "Alice");
        vm.label(BOB, "Bob");
        vm.label(PAYER, "Payer");
        vm.label(address(token), "TestToken");
        vm.label(address(splitwise), "SplitwiseContract");


        // Mint starting balances to users
        token.mint(ALICE, 1000);
        token.mint(BOB, 1000);
    }

    // --- Test Cases ---

    function testCreateGroup() public {
        address[] memory members = new address[](3);
        members[0] = ALICE;
        members[1] = BOB;
        members[2] = PAYER;

        uint256 gid = splitwise.createGroup(members);
        address[] memory stored = splitwise.getGroupMembers(gid);

        assertEq(stored.length, 3);
        assertEq(stored[0], ALICE);
        assertEq(stored[1], BOB);
        assertEq(stored[2], PAYER);
    }

    function testAddExpenseCreatesDebt() public {
        address[] memory members = new address[](3);
        members[0] = ALICE;
        members[1] = BOB;
        members[2] = PAYER;

        uint256 gid = splitwise.createGroup(members);
        // Total expense of 300 split among 3: Alice owes 100, Bob owes 100
        splitwise.addExpense(gid, address(token), 300, PAYER);

        assertEq(splitwise.getOwed(ALICE, PAYER), 100, "Alice must owe Payer 100");
        assertEq(splitwise.getOwed(BOB, PAYER), 100, "Bob must owe Payer 100");
    }

    function testManualRepaymentWorks() public {
        address[] memory members = new address[](2);
        members[0] = ALICE;
        members[1] = PAYER;
        uint256 expenseAmount = 100;

        uint256 gid = splitwise.createGroup(members);
        splitwise.addExpense(gid, address(token), expenseAmount, PAYER);

        // Alice owes 50 (100 / 2 members).
        
        // Alice transfers 60 to Splitwise contract
        vm.prank(ALICE);
        token.transfer(address(splitwise), 60);

        // Alice repays 60 (Contract will cap repayment at 50)
        vm.prank(ALICE);
        splitwise.repay(PAYER, address(token), 60);

        // The remaining debt must be 0 since the full debt of 50 was covered.
        assertEq(splitwise.getOwed(ALICE, PAYER), 0, "Remaining debt must be 0 after full repayment");
    }

    function testOnlyHookCanAutoRepay() public {
        address[] memory members = new address[](2);
        members[0] = ALICE;
        members[1] = PAYER;

        uint256 gid = splitwise.createGroup(members);
        splitwise.addExpense(gid, address(token), 100, PAYER);

        vm.expectRevert("only hook"); 
        splitwise.autoRepay(PAYER, address(token), 50);
    }

    function testAutoRepayByHookWorks() public {
        // Set the current test contract as the hook address to allow it to call autoRepay
        splitwise.setHook(address(this));

        address[] memory members = new address[](2);
        members[0] = ALICE;
        members[1] = PAYER;

        uint256 gid = splitwise.createGroup(members);
        splitwise.addExpense(gid, address(token), 100, PAYER);

        // Transfer tokens to the Test contract so it has the balance to transfer to Splitwise.
        vm.prank(ALICE);
        token.transfer(address(this), 70); 

        // Simulate the fee collection: Test contract transfers tokens to the Splitwise contract
        token.transfer(address(splitwise), 70); 

        // Call autoRepay from the test contract (which is now the hook).
        // Alice owes 50, so 50 will be applied from the 70 balance.
        splitwise.autoRepay(PAYER, address(token), 70); 

        // The remaining debt must be 0 since the full debt of 50 was covered.
        assertEq(splitwise.getOwed(ALICE, PAYER), 0, "Remaining debt must be 0 after full repayment");
    }
}
