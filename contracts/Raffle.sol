pragma solidity >=0.4.21 <0.7.0;
pragma experimental ABIEncoderV2;

//import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import {IBridge} from "./interface/IBridge.sol";
import {ParamsDecoder, ResultDecoder} from "./lib/Decoders.sol";



contract Raffle  {

    event lotteryCompletion(uint256 first, uint256 second, uint256 third, uint256 platformAmount, uint256 firstPrize, uint256 secondPrize, uint256 thirdPrize);
    event YourTicket(uint256 start, uint256 end);
    uint256 public ticketPrice;
    address payable public platformAddress;
    uint256 public totalGivenAmount;
    IBridge public bridge;


    struct Participant {
        address payable addr;
        uint256 ticketNumber;
    }

    struct LotteryForDay {
        address first;  
        address second;
        address third;
        mapping(uint => Participant) participants;
        uint256 totalTicketSold;
        uint256 ticketPrice; 
    }

    mapping(uint => LotteryForDay) public lotteries;
    uint256 public currentLottery = 1;
    uint256 public ticketNum =1;
    using SafeMath for uint256;
    using ResultDecoder for bytes;
    using ParamsDecoder for bytes;


    constructor(uint256 _ticketPrice, IBridge _bridge, address payable _platformAddress) public  {
        ticketPrice = _ticketPrice;
        bridge = _bridge;
        platformAddress = _platformAddress; //platform address "rename" --
    }

    function buyTicket() public payable  returns (uint256, uint256) {
        //Everyone can apply as much as they want and 100 ticket a time.
        require(msg.value%ticketPrice == 0 && msg.value/ticketPrice < 101 && msg.value >0, 
                "Invalid value input"
        );
        uint256 ticketAmount = msg.value/ticketPrice; // 100 tickets at a time and reject 
        uint256 startTicket = ticketNum;
        for(uint128 i = 1; i <= ticketAmount; i++){
            //lotteries[currentLottery].participants.push(Participant(msg.sender));
            lotteries[currentLottery].participants[ticketNum].addr = msg.sender;
            lotteries[currentLottery].participants[ticketNum].ticketNumber = ticketNum;
        
            ticketNum = ticketNum.add(1);
        }    
        uint256 endTicket = ticketNum.sub(1);
        emit YourTicket(startTicket,endTicket);
        return(startTicket,endTicket);

    }

    function ticketCount() external view returns (uint256 totalTicket) { //readonly method for all read state.
        return ticketNum.sub(1);
    }

    function gameInfo(uint256 gameId) external view returns(address First, address Second, address Third, uint participants, uint TicketPrice){
        LotteryForDay memory lottery = lotteries[gameId];
        return (lottery.first,lottery.second,lottery.third,lottery.totalTicketSold,lottery.ticketPrice);
    }


    function setPlatformAddress(address payable _newPlatform) public {  //platform 
        require(_newPlatform != address(0),"Invalid Address");
        platformAddress = _newPlatform;
    }

    function calculateResult(bytes memory data) public returns (uint256, uint256, uint256){
        
        require(
            ticketNum > 10,
            "Must be equal to or greater than 3"
        );

        uint256 totalBalance = address(this).balance;
     
        // Send money to an platform address to cover the costs.
        uint256 platformAmount = totalBalance.mul(20) / 100;
        platformAddress.transfer(platformAmount);
        uint256 totalParticipant = ticketNum.sub(1); 
        uint256 First = random(data,totalParticipant);
        //Needed the use of the mechanism to find two different random number
         uint256 Second = First.add(50) % totalParticipant;
        uint256 Third = Second.add(75) % totalParticipant;   
        address payable firstWinner = lotteries[currentLottery].participants[First].addr;
        uint256 firstPrize = totalBalance.mul(50) / 100;
        firstWinner.transfer(firstPrize);

        address payable secondWinner = lotteries[currentLottery].participants[Second].addr;
        uint256 secondPrize = totalBalance.mul(20) / 100;
        secondWinner.transfer(secondPrize);

        address payable thirdWinner = lotteries[currentLottery].participants[Third].addr;
        uint256 thirdPrize = address(this).balance;
        thirdWinner.transfer(thirdPrize);

        lotteries[currentLottery].first = firstWinner;
        lotteries[currentLottery].second = secondWinner;
        lotteries[currentLottery].third = thirdWinner;
        lotteries[currentLottery].totalTicketSold = ticketNum.sub(1);
        lotteries[currentLottery].ticketPrice = ticketPrice;
        totalGivenAmount += firstPrize + secondPrize + thirdPrize;

        emit lotteryCompletion(First, Second, Third, platformAmount, firstPrize, secondPrize, thirdPrize);
        require(address(this).balance == 0, "Balance should be 0 in order to start a new lottery");
        currentLottery = currentLottery.add(1);
        ticketNum = 1;
        return (First,Second,Third);
    }    

    //Helper Function

    function random(bytes memory _data, uint256 totalParticipant) internal returns(uint256) {
        (
            IBridge.RequestPacket memory latestReq,
            IBridge.ResponsePacket memory latestRes
        ) = bridge.relayAndVerify(_data);

         ParamsDecoder.Params memory params = latestReq.params.decodeParams();
        uint64 oracleScriptID = latestReq.oracleScriptId;
        ResultDecoder.Result memory result = latestRes.result.decodeResult();

         // Check for correct oracleScriptID
        require(
            oracleScriptID ==
                11,
            "ERROR_ORACLE_SCRIPT_ID_DOES_NOT_MATCH_WITH_EXPECTED"
        );
        // Check for correct request parameters
        require(
            params.size ==
                1,
            "ERROR_SIZE_DOES_NOT_MATCH_WITH_EXPECTED"
        );
        string memory randomNumber = result.random_bytes;
        uint256 randomNumberFinal = toint(randomNumber);
        uint256 randNum = randomNumberFinal % totalParticipant;
        return (randNum);  
    } 

    function toint(string memory s) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        uint8 num = uint8(uint256(keccak256(b)));
        result = num;
    }

}

