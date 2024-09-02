//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is CodeConstants,Test {
    uint256 public constant STARTING_BALANCE = 10 ether;
    address payable public PLAYER1 = payable(makeAddr("This is Player 1"));
    address payable public PLAYER2 = payable(makeAddr("This is Player 2"));
    address payable public PLAYER3 = payable(makeAddr("This is Player 3"));
    Raffle public raffle;
    HelperConfig.NetworkConfig networkConfig;

    event PlayerEntered(address indexed player);
    event WinnerSelected(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, networkConfig) = deployRaffle.run();

        vm.deal(PLAYER1, STARTING_BALANCE);
        vm.deal(PLAYER2, STARTING_BALANCE);
        vm.deal(PLAYER3, STARTING_BALANCE);
    }


    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                                  Test constructor                                     */
    ///////////////////////////////////////////////////////////////////////////////////////////


    function testConstructorWorks() public view {
        assertEq(raffle.getEntranceFee(), networkConfig.entranceFee);
        assertEq(raffle.getInterval(), networkConfig.interval);

        // assertEq(raffle.getEntranceFee(), networkConfig.vrfCoordinator);
        // assertEq(raffle.getEntranceFee(), networkConfig.gasLane);
        // assertEq(raffle.getEntranceFee(), networkConfig.subId);
        // assertEq(raffle.getEntranceFee(), networkConfig.callbackGasLimit);
    }
    function testRaffleInitializesInOpenState() public view {
        assertEq(uint256(raffle.getRaffleState()), 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        // assertEq(raffle.getRaffleState(),Raffle.RaffleState.OPEN); why this fails ?
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                              Test EnterRaffle Functions                               */
    ///////////////////////////////////////////////////////////////////////////////////////////

    function testEnterRafflRevertsIfDidNotSendEnough() public {
        //Arrange
        vm.prank(PLAYER1);
        //Act/Assert
        vm.expectRevert(Raffle.Raffle__DidNotSendEnoughFee.selector);
        raffle.enterRaffle();
    }

    function testEnterRaffleRevertIfRaffleIsNotOpen() public {
        //Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();

        // Make sure interval have passed
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        //Assert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    function testEnterRaffleAddsPeopleToArray() public {
        // Arrange
        vm.prank(PLAYER1);
        //Act
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        //assert
        assertEq(raffle.getPlayerWithIndex(0), PLAYER1);
        assertEq(raffle.getNumberOfPlayers(), 1);

    }

    function testEnterRaffleEmitPlayerEnteredEmmit() public {
        //Arrange
        vm.prank(PLAYER1);
        //Act/assert
        vm.expectEmit(true, false, false, false);
        // vm.expectEmit(true, false,false,false, address(raffle));
        emit PlayerEntered(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                              Test checkUpkeep Function                                */
    ///////////////////////////////////////////////////////////////////////////////////////////

    function testCheckUpkeepReturnsFalseIfRaffleHasNoBalance() public {
        vm.roll(block.number+1);
        vm.warp(block.timestamp + networkConfig.interval + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleStateIsCalculating() public {
        //Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");


        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        // assertEq( raffle.getRaffleState() == 1);
        assertEq(uint256(raffle.getRaffleState()), 1);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER);
        // assert(raffleState == Raffle.RaffleState.CALCULATING_WINNER); patricks
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfTimeIntervalHasNotPassed() public{
        //Arrang
        vm.prank(PLAYER1);
        raffle.enterRaffle{value:networkConfig.entranceFee}();
        // vm.wrap(block.number+1);
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);


    }

    function testCheckUpkeepReturnsTrueIfEverythingIsAlright() public {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value:networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.interval+ 1);
        vm.roll(block.number+1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded);

    }


    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                               Test performUpkeep Function                             */
    ///////////////////////////////////////////////////////////////////////////////////////////
    function testPerformUpkeepRevertsIfUpkeepNotNeeded() public{
        //arrange 
        //
        //
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, address(raffle).balance, raffle.getNumberOfPlayers(), raffle.getRaffleState()));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepWorksIfCheckUpkeepIsTrue() public{
        //arrange 
        vm.prank(PLAYER1);
        raffle.enterRaffle{value:networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.interval+ 1);
        vm.roll(block.number+1);

        //Assert
        raffle.performUpkeep("");
    }



    function testPerformUpkeepUpdtesRaffleStteAndEmitRequestIdEvent() public{
        //arrange 
        vm.prank(PLAYER1);
        raffle.enterRaffle{value:networkConfig.entranceFee}();
        vm.warp(block.timestamp + networkConfig.interval+ 1);
        vm.roll(block.number+1);

        //ACT
        vm.recordLogs();

        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // /vrf coordinator also emits the similaar event 
        // that's why our event RequesteRaffleWinner is stored at index 1,
        // 0th topic is always resevered for keccak256("LogCompleted(uint256,bytes)")
        bytes32 requestId = entries[1].topics[1]; // See the defination of Log in Vm.sol



        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) >0);
        assert(uint256(raffleState) ==1);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value:networkConfig.entranceFee}();
        vm.roll(block.number+1);
        vm.warp(block.timestamp+ networkConfig.interval +1);

        _;

    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    /*                               Test fulfill Function                             */
    ///////////////////////////////////////////////////////////////////////////////////////////



    // fulfill function should be run after the performUpkeep function is executed.



    /**
     * for forking test
     * Now we can not control the vrfCoordinator( as we were pretending to be vrfCoordinator so far )
     * So the fulfillRandomWords tests won’t work now.
     * So we can skip these tests.
     */
    modifier skipFork(){
        if(block.chainid!= LOCAL_CHAINID){
            return;
        }
        _;
    }





    function testFulfillRandomWordaCanOnlyBeCalledAfterPerformUpkeep(uint256 requestId) public skipFork raffleEntered{
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        //Only chainlink nodes can call original vrfCoordinator's fulfillRandomWords function
        //But V2_5mock allows us to do so
        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords( requestId /**randomely choosen requestId */, address(raffle));

        // vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords( 1 /**randomely choosen requestId */, address(raffle));

    }


    function testFulfillRandomWordsPicksWinnerAndResetPlayersArrayAndSendMoneyToWinner() public skipFork{
        uint256 noOfPlayers = 4;
        address expectedWinner = address(1);
        for(uint256 i = 1; i <= noOfPlayers; i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether );
            raffle.enterRaffle{value:networkConfig.entranceFee}();
        }
        vm.warp(block.timestamp + networkConfig.interval + 1);
        vm.roll(block.number + 1);
        uint256 startingTimestamp = raffle.getLastTimestamp();
        uint256 startingBalance = expectedWinner.balance;



        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.logBytes32(entries[1].topics[1]);
        console.log("dddddddd %d",raffle.getNumberOfPlayers());
        bytes32 requestId = entries[1].topics[1];




        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).fulfillRandomWords( uint256(requestId), address(raffle));
        //Assert
        address recentWinner = raffle.getRecentWinner();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimestamp();
        uint256 totalPrizeInRaffle = noOfPlayers * networkConfig.entranceFee;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        console.log("dddddddd %d",raffle.getNumberOfPlayers());


        for(uint256 i = 1; i <= 4; i++){
            if(recentWinner == address(uint160(i))){
                expectedWinner = address(uint160((i)));
                break;
            } 
        }


        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + totalPrizeInRaffle);
        assert(endingTimestamp > startingTimestamp);
        assert(raffle.getNumberOfPlayers() == 0);




    }










}
