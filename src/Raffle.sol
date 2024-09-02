//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A simple Lottery Contract
 * @author @tusharr1411
 * @notice This contract is for creating simple lottery
 * @dev Implements chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                                     Errors                                            */
    ///////////////////////////////////////////////////////////////////////////////////////////
    error Raffle__DidNotSendEnoughFee();
    error Raffle__NotEnoughTimePassed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 raffleBlance, uint256 playerLength, uint256 raffleState);

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                                     type declarations                                 */
    ///////////////////////////////////////////////////////////////////////////////////////////
    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                                     State Variables                                   */
    ///////////////////////////////////////////////////////////////////////////////////////////
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //duration of the lottery in seconds
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address payable private s_recentWinner;

    // Chainlink VRF variables
    bytes32 private immutable i_keyHash; //for gasLane
    uint256 private immutable i_subId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    // bytes private immutable i_extraArgs;

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                                       Events                                          */
    ///////////////////////////////////////////////////////////////////////////////////////////
    event PlayerEntered(address indexed player);
    event WinnerSelected(address indexed winner);
    event RequesteRaffleWinner(uint256 indexed requestId);

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                                     Constructor                                       */
    ///////////////////////////////////////////////////////////////////////////////////////////
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subId = subId;
        i_callbackGasLimit = callbackGasLimit;
        // i_extraArgs = extraArgs;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__DidNotSendEnoughFee();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit PlayerEntered(msg.sender);
    }

    /**
     * @dev this is the function chainlink nodes will call to see if lottery is ready to have a winner picked.
     * The following should be true in order to for upkeepNeed to be true.
     * 1. timeInterval has passed.
     * 2. the lottery is open
     * 3. the contract has ETH.
     * 4. the players have entered.
     * 5. Your subscription has Link ( Implicitly)
     * @param - ignored
     * @return upkeepNeeded : true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(bytes memory /*calldata*/ /* performData */ ) public view returns (bool upkeepNeeded, bytes memory /*performData*/ ){
        upkeepNeeded = (block.timestamp-s_lastTimeStamp>i_interval) && (s_players.length > 0) && (address(this).balance > 0) && (s_raffleState == RaffleState.OPEN);
        return (upkeepNeeded, ""); //
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        // if (block.timestamp - s_lastTimeStamp < i_interval) {
        //     revert Raffle__NotEnoughTimePassed();
        // }

        (bool upkeepNeeded,) = checkUpkeep(""); // string does not work with calldata that's why checkupkeep parameter is set to memory

        if (!upkeepNeeded) {revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));}
        s_raffleState = RaffleState.CALCULATING_WINNER;
        /**
         *     bytes32 keyHash;
         *     uint256 subId;
         *     uint16 requestConfirmations;
         *     uint32 callbackGasLimit;
         *     uint32 numWords;
         *     bytes extraArgs;
         */
        /**
         *   VRFV2PlusClient.RandomWordsRequest is a struct from VRFV2PlusClient Library
         *   vrfCoordinator is an Onchain deployed contract address which we have passed to abstract contract VRFConsumerBaseV2Plus
         *   So the abstract VRFConsumerBaseV2Plus wrapped it to interface of IVRFCoordinator and make a intractable contract named s_vrfCoordinator
         *   so that we can call it's request function and it can callback fulfillFunction
         */

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        emit RequesteRaffleWinner(requestId); // vrf coordinator also emits the similaar event
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        s_recentWinner = s_players[winnerIndex];
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        emit WinnerSelected(s_recentWinner);
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        require(success);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                                     Getter Function                                   */
    ///////////////////////////////////////////////////////////////////////////////////////////

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayerWithIndex(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint32) {
        return NUM_WORDS;
    }

    function getRequestCinfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}

