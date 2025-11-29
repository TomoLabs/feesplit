TomoLabs – FeeToSplitter Hook
A Revenue-Sharing Uniswap v4 Hook for Automated Fee Splitting

This repository contains two smart contracts that together enable creator-aligned liquidity on Uniswap v4.
Swap fees generated inside a pool are instantly routed and distributed to predefined recipients using basis-point (BPS) allocations.

 Overview

This module combines:

FeeSplitter.sol – Splits any ERC-20 token among multiple recipients according to fixed percentages.

FeeToSplitterHook.sol – A Uniswap v4 Hook that intercepts swap fees and forwards them to the FeeSplitter in real time.

This system enables:

Creator / partner revenue-sharing

Automated LP fee routing

DAO-native distribution pipelines

Transparent, programmable fee economics

🔥 Key Features
✔ Automatic Fee Sharing

On every swap, the hook reads the fee delta and calls:

FeeSplitter.distribute(token, amount);


Fees are shared immediately — no manual claim process.

✔ Basis-Point (BPS) Share Configuration

Recipient percentages are defined in basis points:

10000 BPS = 100%

Shares must sum to exactly 10000

This ensures precise, tamper-proof distribution.

✔ Flexible Recipients

Supports any combination of:

Creators

DAO multisigs

LP managers

Protocol-owned wallets

Foundation teams

✔ Native Uniswap v4 Hook Integration

Implements the exact v4 hook permission schema.
Only afterSwap is enabled, keeping the hook minimal and gas-efficient.

 Contracts
### FeeSplitter.sol

A minimal contract that distributes incoming ERC-20 tokens across recipients.

Constructor

constructor(address[] memory _recipients, uint256[] memory _shares);


Distribution Function

function distribute(address token, uint256 amount) external;


Each recipient receives:

(amount * share[i]) / 10000

FeeToSplitterHook.sol

A Uniswap v4 hook that runs on every swap (afterSwap):

Responsibilities:

Reads swap fee deltas (delta.amount0())

If positive fees exist, forwards them to FeeSplitter

Enables only necessary permissions

Integrates seamlessly with PoolManager

This architecture ensures on-chain fee routing without needing any LP interaction.

 Directory Structure
src/
│── FeeSplitter.sol
└── FeeToSplitterHook.sol

script/
└── DeployFeeHook.s.sol

 Configuration

Edit script/DeployFeeHook.s.sol to configure:

Parameter	Example	Description
Pool Manager	0xA7B8e01F655C72F2fCf7b0b8F9E0633D5c86B8Dc	Uniswap v4 PoolManager address
Fee Token	0x00000000000000000000000000000000000000AA	ERC-20 token to distribute fees in
Recipients	0x27eB1474… 0x00000022…	Fee receivers
Shares	6000 / 4000	60% + 40%
 Installation
git clone https://github.com/TomoLabs/Hooks.git
cd Hooks

forge install
forge build

 Deployment

Example:

forge script script/DeployFeeHook.s.sol \
  --rpc-url https://sepolia.infura.io/v3/<key> \
  --broadcast -vvvv


This deploys:

FeeSplitter

FeeToSplitterHook

 How It Works (Swap Lifecycle)

User swaps in a Uniswap v4 pool.

PoolManager triggers the hook afterSwap.

Hook reads the delta:

delta.amount0()


If positive fees were collected:
→ The hook calls:

splitter.distribute(feeToken, uint256(int256(amount0)));


FeeSplitter distributes fees according to BPS percentages.

 Example Log Event
FeeDistributed(
    token = 0x00000000000000000000000000000000000000AA,
    totalAmount = 12345
)

 Testing
forge test -vvvv


Recommended tests:

Correct fee splitting

Hook permission validation

Swap callback logic

Revert when shares ≠ 10000

📄 License

MIT License

 Credits

Built by TomoLabs —
Creator-aligned Web3 liquidity infrastructure.
