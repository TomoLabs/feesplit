// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";

import {Splitwise} from "../src/Splitwise.sol";
import {SplitwiseHook} from "../src/SplitwiseHook.sol";
import {ISplitwise} from "../src/SplitwiseHook.sol";

contract DeploySplitwise is Script {
    // Canonical CREATE2 deployer
    address constant CREATE2_DEPLOYER =
        0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        vm.startBroadcast();

        
        //  CONFIG — UPDATE THESE
       

        //  Uniswap v4 PoolManager (MAINNET)
        IPoolManager poolManager =
            IPoolManager(0xA7B8e01F655C72F2fCf7b0b8F9e0633D5c86B8Dc);

        // BILL OWNER / PAYER (WHO GETS REIMBURSED)
        address payer = 0x27EB14742Ec8Fe485492a5b553EC9d13DB5f0aF4;

        
        //  1. DEPLOY SPLITWISE LEDGER
        

        Splitwise splitwise = new Splitwise();

       
        //  2. MINE DETERMINISTIC HOOK ADDRESS (REQUIRED BY V4)
        

        uint160 flags = Hooks.AFTER_SWAP_FLAG;

        bytes memory constructorArgs = abi.encode(
            address(poolManager),
            ISplitwise(address(splitwise)),
            payer
        );

        (address minedHook, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(SplitwiseHook).creationCode,
            constructorArgs
        );

        
        //  3. DEPLOY SPLITWISE HOOK WITH CREATE2
       

        SplitwiseHook hook =
            new SplitwiseHook{salt: salt}(
                poolManager,
                ISplitwise(address(splitwise)),
                payer
            );

        require(address(hook) == minedHook, "CREATE2 mismatch");

        
        //  4. LINK HOOK → SPLITWISE (CRITICAL)
        

        splitwise.setHook(address(hook));

        vm.stopBroadcast();
    }
}

