//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

//     uint256 entranceFee,
//     uint256 interval,
//     address vrfCoordinator,
//     bytes32 gasLane,
//     uint256 subId,
//     uint32 callbackGasLimit
//
contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig.NetworkConfig memory) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        if (networkConfig.subId == 0) {
            //create subscription.
            CreateSubscription createSubscription = new CreateSubscription();

            (networkConfig.subId, networkConfig.vrfCoordinator) =
                createSubscription.createSubscription(networkConfig.vrfCoordinator, networkConfig.account);
            // fund it
            FundSubscription fundSubscription = new FundSubscription();

            fundSubscription.fundSubscription(
                networkConfig.vrfCoordinator, networkConfig.linkTokenAddress, networkConfig.subId, networkConfig.account
            );
        }

        vm.startBroadcast(networkConfig.account);

        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subId,
            networkConfig.callbackGasLimit
        );

        vm.stopBroadcast();

        // Add consumer to it
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), networkConfig.subId, networkConfig.vrfCoordinator, networkConfig.account);

        return (raffle, networkConfig);
    }
}
