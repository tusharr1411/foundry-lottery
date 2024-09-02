//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
// import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        (uint256 subId,) = createSubscription(vrfCoordinator, networkConfig.account);
        return (subId, vrfCoordinator);
    }


    function createSubscription(address _vrfCoordinator,address account) public returns (uint256, address) {
        console.log("Creating subscriptoon for chainId :", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Created Subsrciption with  Sub_id: ", subId);
        console.log("Please update your subscription id in your Network Config");
        return (subId, _vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 2 ether; // 2 links because link does also come with 18 decimals

    function fundSubscriptionWithNetworkConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        address linkTokenAddress = networkConfig.linkTokenAddress;
        uint256 subId = networkConfig.subId;

        fundSubscription(vrfCoordinator, linkTokenAddress, subId, networkConfig.account);
    }

    function fundSubscription(address vrfCoordinator, address linkTokenAddress, uint256 subId, address account) public {
        console.log("Funding Subscription with subscriptionId :", subId);
        console.log("Using vrfCoordinator :", vrfCoordinator);
        console.log("On chain ID :", block.chainid);

        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast();

            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT*100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            // VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId,FUND_AMOUNT);
            LinkTokenInterface(linkTokenAddress).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionWithNetworkConfig();
    }
}

contract AddConsumer is Script, CodeConstants {
    function addConsumerWithNetworkConfig(address consumer) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subId = networkConfig.subId;
        addConsumer(consumer, subId, vrfCoordinator,networkConfig.account);
    }

    function addConsumer(address consumer, uint256 subId, address vrfCoordinator,address account) public {
        console.log("Adding Consumer :", consumer);
        console.log("To vrfCoordinator :", vrfCoordinator);
        console.log("on subscriptionId :", subId);
        console.log("On chain ID :", block.chainid);
        // address recentdDeployedAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }

    function run() external {
        address recentdDeployedAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerWithNetworkConfig(recentdDeployedAddress);
    }
}
