
 # TomoLabs
 
TomoLabs converts Uniswap v4 swap fees into an autonomous on-chain debt repayment engine using a permissioned hook and a non-custodial expense ledger.

 ✅ Live on Ethereum Mainnet  
 ✅ Contracts Verified on Etherscan  
 ✅ End-to-End Fee → Debt → Repayment Flow Operational  
 ✅ Production-Grade Uniswap v4 Hook  

 This hook is live and deployed on Ethereum mainnet with fully verified contracts.



  ## OVERVIEW

TomoLabs introduces a first-of-its-kind on-chain system where real-world group debt is repaid passively through DEX trading activity using programmable Uniswap v4 Hooks. Instead of relying on deadlines, reminders, or manual transfers, financial settlement is embedded directly into live market liquidity. This creates a new DeFi primitive: **Debt as a Function of Trading Volume** — where every swap becomes a settlement event.

         ✨ Live Hook on Ethereum • ⚙️ Powered by Uniswap v4 Hooks  

  ## CORE PRINCIPLES

1.) Trustless Debt Settlement:
All group expenses, member balances, and repayments are enforced entirely by smart contracts, eliminating reliance on off-chain trust, manual accounting, or centralized intermediaries.

2.) Automated Fee-to-Debt Conversion:
Swap fees captured via Uniswap v4 Hooks are automatically routed into the Splitwise contract, converting passive trading activity into real-time debt repayments without user intervention.

3.) Composable DeFi Integration:
The system is natively composable with Uniswap v4 and EigenLayer-based restaking flows, enabling Splitwise to plug directly into permissionless liquidity, yield, and restaking infrastructure.

4.) Non-Custodial & Permissioned Control:
Users retain full control of their funds at all times, while sensitive repayment automation is strictly permissioned to the registered hook, preventing unauthorized fund movement.

5.) Transparent, On-Chain Accountability:
Every expense, repayment, and auto-settlement action is emitted as on-chain events, enabling block explorers, DAOs, and analytics tools to verify all financial flows in real time.

  ## FEATURES

1. Trustless Group Expense Management:

   Creates on-chain expense groups with multiple members.
   Records shared expenses with:

    1) Group ID

    2) Token address

    3) Total amount

    4) Designated payer
   
    Automatically calculates proportional debt per member.


2. Uniswap v4 Fee Capture via Hooks:

   Integrates natively with Uniswap v4 Hooks to:

    1) Intercept swaps via afterSwap

    2) Capture protocol swap fees directly from the Pool Manager

    3) Support both token0 and token1 fee flows
   
    This enables DEX trades to become a repayment engine.


3. Automated Fee-to-Debt Repayment Engine:

   Captured swap fees are:

   1) Automatically routed into the Splitwise contract

   2) Converted into real-time repayments for outstanding debts

   3) Executed without any user transaction or approval
      
   This creates a passive, always-on repayment system.


4. Permissioned Auto-Repayment Security:

   Only the authorized SplitwiseHook can trigger autoRepay().

   1) Protection includes:

   2) On-chain hook verification

   3) Revert protection for unauthorized callers
   
   This ensures zero-exploit surface for forced repayments.


5. Manual Repayment Support:

   Users can also repay debts manually via:

   1) repay(creditor, token, amount)
      
   Supports:

   2) Partial repayments

   3) ERC-20 token-based repayments

   4) Real-time debt reduction updates
  

6. Multi-Token Debt Tracking

   Tracks debts:

    1) Per user

    2) Per creditor

    3) Per token
   
    Enables:

    4) Multi-asset group expenses (USDC, ETH, LSTs, etc.)

    5) Segmented settlement per asset class
  



7. Event-Driven On-Chain Transparency:   

     Emits verifiable events for:

      1) GroupCreated

      2) ExpenseAdded

      3) ManualRepayment

      4) AutoRepayment

      5) HookSet
         
      Enables:

      6) Subgraph indexing

      7) DAO dashboards

      8) Real-time analytics
         

8. Non-Custodial Fund Flow:

     Users never relinquish wallet control:

      1) Hook only routes protocol fees

      2) Users control all personal repayments

      3) No pooled custody risk
          
      Fully aligned with DeFi self-sovereignty principles.
   

9. Gas-Efficient Settlement Design:

      Optimized for:
    
      1) Batch group creation

      2) Single-call fee harvesting

      3) Minimal storage writes
         
      Built for high-frequency swap environments.


## USAGE GUIDE


1. Create an On-Chain Expense Group:

     Initialize a new group by providing member addresses.
     The Splitwise contract assigns a groupId and stores all participants for future expense-sharing.
   

2. Add Shared Expenses:

     Record expenses directly on-chain by calling addExpense() with:

      1) Group ID

      2) Token used for payment

      3) Total expense amount

      4) The payer’s address

     The contract automatically splits the amount among all members and updates internal debt balances.
   

3. Deploy & Link the Splitwise Hook

     Deploy the SplitwiseHook with:

      1) PoolManager address

      2) Splitwise contract address

      3) Default bill payer

      Then call setHook() on Splitwise to authorize the hook.
   
      This enables the system to accept automated repayments.
   

4. Start Trading on the Uniswap v4 Pool

     Users interact with the Uniswap v4 pool as usual.
   
     Whenever a swap occurs:

      1) The hook intercepts afterSwap

      2) Extracts the swap fee generated by the trade

      3) Sends the fee to Splitwise as repayment on the payer’s behalf

     This converts every trade into a passive debt-reduction event.
   

5. Automatic Fee-Based Repayments

     The SplitwiseHook calls autoRepay() with:

      1) Token address

      2) Amount of fee captured

      3) Designated payer

     Splitwise verifies hook permissions and updates the debt ledger entirely on-chain.
   

6. Manual Repayment

     If users want to clear debt faster, they can manually repay using:

      1) repay(creditor, token, amount)

     The contract recalculates remaining debt balances in real time.
   

7. View Debt Balances

     Anyone can query:

      1) Who owes whom

      2) How much

      3) In which token
         
     using getOwed() and getGroupMembers().

     This makes expense history fully transparent and audit-friendly.
   

9. Real-Time Automated Settlement

     As more swaps occur in the Uniswap pool:

      1) Fee revenue continues flowing into Splitwise

      2) Debts shrink automatically

      3) Groups settle expenses without requiring members to take any manual action

    Your DeFi activity becomes a continuous settlement engine.
   


## ARCHITECTURE 

         ┌──────────── User Swap on Uniswap ─────────────┐
                                  │
                        ┌─────────▼─────────┐
                        │  Uniswap v4 Pool  │
                        │  (Liquidity AMM)  │
                        └─────────┬─────────┘
                                  │ afterSwap()
                        ┌─────────▼─────────┐
                        │  SplitwiseHook    │ ◄── Hook Authorization
                        │  (Automation)     │
                        └─────────┬─────────┘
                                  │ PoolManager.take()
                        ┌─────────▼─────────┐
                        │  Fee Extraction   │ ◄── Token0 / Token1 Logic
                        └─────────┬─────────┘
                                  │ autoRepay()
                 ┌────────────────▼────────────────┐
                 │        Splitwise Contract        │ ◄── On-chain Debt Ledger
                 │  - Groups & Members              │
                 │  - Expense Tracking               │
                 │  - Per-User Debt Balances         │
                 │  - Manual + Auto Repayment        │
                 └───────────────┬───────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  Bill Payer Settlement    │ ◄── Trading fees reduce debt
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  Event & Indexing Layer   │ ◄── The Graph / Dashboards
                    └───────────────────────────┘


## SECURITY MODEL

- The Splitwise contract only accepts autoRepay() calls from the authorized SplitwiseHook.
- The hook is set once via setHook() and cannot be spoofed.
- All debt updates are fully on-chain and verifiable.
- No user funds are ever held in custody by the system.
- All swap fees are pulled directly from the Uniswap v4 PoolManager.


## Testing & Validation

- Hook logic tested with Foundry
- Fee capture and repayment validated on Ethereum mainnet
- All state transitions are fully on-chain and verifiable via events


## References

- [EigenLayer](https://app.eigenlayer.xyz/)
- [Uniswap v4 Hooks](https://docs.uniswap.org/contracts/v4/concepts/hooks)
- [OpenZeppelin](https://www.openzeppelin.com/)



## Mainnet Deployment (Ethereum)

   **Splitwise Core Contract (Debt Engine):**  

             0x9e9ee1221867413486b8c4a21c185b09b5b28c2f  

   https://etherscan.io/address/0x9e9ee1221867413486b8c4a21c185b09b5b28c2f  


   **Splitwise Uniswap v4 Hook (Auto Fee Repayment):**  

             0x910880539c2cdba3f538dbb753b698555d108040

   https://etherscan.io/address/0x910880539c2cdba3f538dbb753b698555d108040  



