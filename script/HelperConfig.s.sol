//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant ENTRANCE_FEE = 0.01 ether;
    uint256 public constant INTERVAL = 30 seconds; // will be converted in seconds implicitly
    uint256 public constant LOCAL_CHAINID = 31337;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;

    // Mock Values for VRF coordinator
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;//Link-Eth Price
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__INVALID_CHAIN_ID();

    /*//////////////////////////////////////////////////////////////
                            Types
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subId;
        uint32 callbackGasLimit;
        address linkTokenAddress;
        address account;
    }

    /*//////////////////////////////////////////////////////////////
                            Global Variable
    //////////////////////////////////////////////////////////////*/

    NetworkConfig public localNetworkConfig;

    mapping(uint256 => NetworkConfig) chainIdToNetworkConfig;

    /*//////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    constructor() {
        chainIdToNetworkConfig[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthNetworkConfig();
        chainIdToNetworkConfig[ETH_MAINNET_CHAIN_ID] = getMainnetEthNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    function addNetworkToNetworkConfigs(uint256 chainId, NetworkConfig memory networkConfig) public {
        chainIdToNetworkConfig[chainId] = networkConfig;
    }

    function getNetworkConfig() public returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }

    function getNetworkConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainIdToNetworkConfig[chainId].vrfCoordinator != address(0)) {
            return chainIdToNetworkConfig[chainId];
        } else if (chainId == LOCAL_CHAINID) {
            return getOrCreateAnvilNetworkConfig();
        } else {
            revert HelperConfig__INVALID_CHAIN_ID();
        }
    }

    //ETH-MAINNET
    function getMainnetEthNetworkConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a, //200 gwei keyhash
            gasLane: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9,
            subId: 82921786646586951716443343528345144059751065535172619558924084025857470862845, // why ? let's fugure it out- our script will automatically create if we don't have
            callbackGasLimit: 500000, // that would be enough four our pick
            linkTokenAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account:0x325e974B12e37eB8a2Bbc785a01DCD541B77A5dB
        });
    }

    // SEPOLIA
    function getSepoliaEthNetworkConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //100gwei
            subId: 82921786646586951716443343528345144059751065535172619558924084025857470862845,
            callbackGasLimit: 500000,
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account:0x325e974B12e37eB8a2Bbc785a01DCD541B77A5dB
        });
    }

    //ANVIL
    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        console.log(unicode"⚠️ You have deployed a mock conract!");
        console.log("Make sure this was intentional");

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        MockLinkToken mockLinkToken = new MockLinkToken();
        vm.stopBroadcast();

        // console.log("You have deployed a mock Link Token");

        localNetworkConfig = NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            gasLane: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9, // does not matter for mocks
            subId: 0, // we gave to fix this
            callbackGasLimit: 500000, // doesn't matter for mocks
            linkTokenAddress: address(mockLinkToken),
            account:0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return localNetworkConfig;
    }
}
