// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

contract GoldenNumber is VRFV2WrapperConsumerBase {
    address private constant LINK_ADDRESS =
        address(0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06);
    address private constant VRF2WRAPPER_ADDERSS =
        address(0x699d428ee890d55D56d5FC6e26290f3247A762bd);
    uint32 private constant CALLBACK_GAS_LIMIT = 3000000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 constant BET_PRICE = 0.05 ether;
    uint256 constant PRIZE = 0.5 ether;
    uint256 constant TOKEN_BURN = 0.1 ether;
    uint256 constant REVENUE = 0.05 ether;

    address public RevenueShareWallet;

    uint256 public constant ROUND_SLOTS = 13;

    struct Round {
        address[ROUND_SLOTS] participants;
        uint256 betCount;
        uint256 vrfRequestId;
        uint256 randomNumber;
        address winner;
    }
    uint256 public totalRounds;
    Round[] public rounds;
    mapping(uint256 => uint256) reqIdToRoundId;

    constructor() VRFV2WrapperConsumerBase(LINK_ADDRESS, VRF2WRAPPER_ADDERSS) {}

    function bet(uint256 number) external payable {
        Round storage round = rounds[totalRounds];
        require(msg.value == BET_PRICE, "Price doesnt not match.");
        round.participants[number] = msg.sender;
        round.betCount++;
        if (round.betCount == ROUND_SLOTS) {
            uint256 requestId = requestRandomness(
                CALLBACK_GAS_LIMIT,
                REQUEST_CONFIRMATIONS,
                1
            );
            round.vrfRequestId = requestId;
            reqIdToRoundId[requestId] = totalRounds;
            totalRounds++;
        }
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 roundId = reqIdToRoundId[_requestId];
        Round storage round = rounds[roundId];
        round.randomNumber = _randomWords[0];
        round.winner = round.participants[round.randomNumber % ROUND_SLOTS];
        (bool success, ) = payable(round.winner).call{value: PRIZE}("");
        require(success, "Transfer failed");
    }
}
