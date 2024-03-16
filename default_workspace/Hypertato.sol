// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Import ERC721 interface for Hot Potato NFT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Import Hyperlane interface
interface Hyperlane {
    function crossChainTransfer(address _fromToken, address _from, address _toToken, uint _amount, bytes calldata _data) external;
    function isTransferComplete(address _toToken, uint _transferId) external returns (bool);
}

interface IMailbox {
    // ============ Events ============
    /**
     * @notice Emitted when a new message is dispatched via Hyperlane
     * @param sender The address that dispatched the message
     * @param destination The destination domain of the message
     * @param recipient The message recipient address on `destination`
     * @param message Raw bytes of message
     */
    event Dispatch(
        address indexed sender,
        uint32 indexed destination,
        bytes32 indexed recipient,
        bytes message
    );

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Emitted when a new message is dispatched via Hyperlane
     * @param messageId The unique message identifier
     */
    event DispatchId(bytes32 indexed messageId);
}

contract HotPotato is ERC721 {
    address public owner;
    address public currentHolder;
    uint public expirationTime;
    uint public duration;
    uint public rewardAmount;
    uint public maxPasses;
    uint public passes;
    uint public potatoId;
    uint public totalEarnings;
    mapping(address => uint) public prizePool;
    address public hyperlaneAddress; // Address of the Hyperlane contract
    
    event Pass(address indexed from, address indexed to, uint expirationTime, uint potatoId, uint rewardAmount);
    event Explode(address indexed holder, uint potatoId, uint totalEarnings);
    event GameLengthReached(uint totalEarnings);
    event Payout(uint totalEarnings);
    
    constructor(uint _duration, uint _rewardAmount, address _hyperlaneAddress) ERC721("HotPotato", "POTATO") {
        owner = msg.sender;
        duration = _duration;
        expirationTime = block.timestamp + duration;
        rewardAmount = _rewardAmount;
        hyperlaneAddress = _hyperlaneAddress;
        maxPasses = 0; // Default maximum passes
    }
    
    modifier onlyHost() {
        require(msg.sender == owner, "Only the host can call this function");
        _;
    }
    
    // Other functions remain the same...
    
    function pass(address _to) external {
        require(msg.sender == currentHolder, "You are not the current holder of the potato!");
        require(block.timestamp < expirationTime, "The potato has expired!");
        

        // Calculate reward if potato is passed within duration
        uint timeLeft = expirationTime - block.timestamp;
        uint reward = timeLeft > 0 ? rewardAmount : 0;

        // Distribute reward from prize pool
        if (reward > 0) {
            require(prizePool[currentHolder] >= reward, "Insufficient funds in prize pool");
            prizePool[currentHolder] -= reward;
            payable(currentHolder).transfer(reward);
            totalEarnings -= reward;
        }

        currentHolder = _to;
        expirationTime = block.timestamp + duration;
        passes++; // Increment passes

        emit Pass(msg.sender, _to, expirationTime, potatoId, reward);

        // Call Hyperlane to initiate cross-chain transfer
        bytes memory _toBytes = abi.encodePacked(_to);
        IMailbox(hyperlaneAddress).dispatch(
            1, // destinationDomain
            bytes32(uint256(keccak256(_toBytes))), // recipientAddress
            abi.encode(msg.sender, _to, 1, bytes("")) // messageBody
        );

    if (passes >= maxPasses) {
            emit GameLengthReached(totalEarnings);
        }
    }
}