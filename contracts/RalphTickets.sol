// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract RalphTickets is VRFV2WrapperConsumerBase, Ownable, ReentrancyGuard {
    address public constant DEAD_ADDRESS = address(0xdead);
    address public constant UNISWAPV2_ROUTER02_ADDRESS =
        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address private constant LINK_ADDRESS =
        address(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    address private constant VRF2WRAPPER_ADDERSS =
        address(0x708701a1DfF4f478de54383E49a627eD4852C816);
    uint32 private constant CALLBACK_GAS_LIMIT = 2_000_000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 constant BET_PRICE = 0.02 ether;
    uint256 constant PRIZE = 0.21 ether;
    uint256 constant TOKEN_BURN = 0.03 ether;
    uint256 constant REVENUE = 0.06 ether;

    IERC20 public token;
    IUniswapV2Router02 public router =
        IUniswapV2Router02(address(UNISWAPV2_ROUTER02_ADDRESS));

    address public revenueShareWallet;

    uint256 public constant ROUND_SLOTS = 15;

    struct Round {
        address[ROUND_SLOTS] participants;
        uint256 buyCount;
        uint256 vrfRequestId;
        uint256 randomNumber;
        address winner;
    }
    uint256 public totalRounds;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => uint256) reqIdToRoundId;

    event BuyTicket(uint256 roundId, address participant, uint256 number);
    event RoundFinished(uint256 roundId, Round round);

    constructor(
        address tokenAddress
    ) VRFV2WrapperConsumerBase(LINK_ADDRESS, VRF2WRAPPER_ADDERSS) {
        token = IERC20(tokenAddress);
        require(
            IERC20(LINK_ADDRESS).approve(
                VRF2WRAPPER_ADDERSS,
                type(uint256).max
            ),
            "Approve failed"
        );
    }

    function buyTicket(uint256 number) external payable {
        Round storage round = rounds[totalRounds];
        require(msg.value == BET_PRICE, "Price does not match");
        require(
            round.participants[number] == address(0),
            "The ticket is already sold"
        );
        round.participants[number] = msg.sender;
        round.buyCount++;
        emit BuyTicket(totalRounds, msg.sender, number);
        if (round.buyCount == ROUND_SLOTS) {
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
    ) internal override nonReentrant {
        uint256 roundId = reqIdToRoundId[_requestId];
        Round storage round = rounds[roundId];
        round.randomNumber = _randomWords[0];
        round.winner = round.participants[round.randomNumber % ROUND_SLOTS];
        (bool success1, ) = payable(round.winner).call{value: PRIZE}("");
        (bool success2, ) = payable(revenueShareWallet).call{value: REVENUE}(
            ""
        );
        burnToken();
        require(success1 && success2, "Transfer failed");
        emit RoundFinished(roundId, round);
    }

    function burnToken() internal {
        address WETH = router.WETH();
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(token);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: TOKEN_BURN
        }(0, path, DEAD_ADDRESS, block.timestamp + 15 minutes);
    }

    function withdrawEther() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Transfer failed"
        );
    }

    function getRoundParticipants(
        uint256 roundId
    ) external view returns (address[] memory participants) {
        Round storage round = rounds[roundId];
        participants = new address[](ROUND_SLOTS);
        for (uint256 i = 0; i < ROUND_SLOTS; i++) {
            participants[i] = round.participants[i];
        }
    }
}
