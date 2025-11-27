// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol"; // <-- CRITICAL IMPORT FOR CREATE2
import {FeeSplitter} from "../src/FeeSplitter.sol";
import {FeeToSplitterHook} from "../src/FeeToSplitterHook.sol";

contract DeployFeeHook is Script {

    address[] public rec; 
    uint256[] public shares;
    
    // Standard CREATE2 deployer address on many EVM chains.
    // **Verify this address for your specific deployment network.**
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        vm.startBroadcast();

        // 1. SETUP CONTRACTS & ARRAYS
        
        // Pool Manager address
        IPoolManager poolManager =
            IPoolManager(0xA7B8e01F655C72F2fCf7b0b8F9e0633D5c86B8Dc);

        // Token used for fees
        address token = 0x00000000000000000000000000000000000000AA;

        // Allocate space for 2 elements and populate
        rec = new address[](2); 
        rec[0] = 0x27EB14742Ec8Fe485492a5b553EC9d13DB5f0aF4;
        rec[1] = 0x0000000000000000000000000000000000000022;

        shares = new uint256[](2); 
        shares[0] = 6000;
        shares[1] = 4000;

        // Deploy FeeSplitter (standard CREATE deployment is fine for this utility contract)
        FeeSplitter splitter = new FeeSplitter(rec, shares);


        // 2. DETERMINISTIC HOOK DEPLOYMENT (REQUIRED BY V4)
        
        // Define the required flag for your hook (afterSwap)
        uint160 flags = Hooks.AFTER_SWAP_FLAG; 

        // Encode the constructor arguments for HookMiner
        bytes memory constructorArgs = abi.encode(
            address(poolManager), 
            token, 
            address(splitter)
        );
        
        // Use HookMiner to find the correct salt for the deterministic address
        (address minedHookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(FeeToSplitterHook).creationCode,
            constructorArgs
        );

        // Deploy the hook using the found salt (triggers CREATE2 via the deployer)
        FeeToSplitterHook hook = new FeeToSplitterHook{salt: salt}(
            poolManager, 
            token, 
            splitter
        );
        
        // Verification: Ensure the deployed address matches the mined address
        require(address(hook) == minedHookAddress, "Hook address mismatch during CREATE2 deployment.");

        vm.stopBroadcast();
    }
}