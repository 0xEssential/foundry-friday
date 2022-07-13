// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "essential-contracts/contracts/fwd/EssentialERC2771Context.sol";

contract AnOnchainGame is EssentialERC2771Context {
    // Constants
    uint8 public constant teamCount = 3;
    uint256 public constant turnLength = 12 hours;

    // Storage
    uint256 public gameStart;
    uint256 public playerCount;
    mapping(address => uint8) public playerTeam;
    mapping(address => uint256) public playerLastMove;
    mapping(uint16 => uint16[]) public adjacentSpaces;
    mapping(uint16 => uint8) public controlledSpaces;
    mapping(uint8 => uint16[]) public roundBattleSpaces;
    mapping(address => uint16) public playerLocation;

    // Events
    event Registered(address indexed player, address nftContract, uint256 nftTokenId);
    event Moved(address indexed player, uint16 spaceId);

    // Structs
    struct Space {
        uint16 spaceId;
        uint16[] adjacentSpaces;
    }

    constructor(address trustedForwarder) EssentialERC2771Context(trustedForwarder) {
        // TODO:
        // • start game at ideal time
        // • set controlledSpaces
        gameStart = block.timestamp;
    }

    function setMap(Space[] calldata spaces) external onlyOwner {
        uint256 count = spaces.length;
        for (uint256 index = 0; index < count; index++) {
            Space memory space = spaces[index];
            adjacentSpaces[space.spaceId] = space.adjacentSpaces;
        }
    }

    function register() external onlyForwarder {
        require(playerLocation[_msgSender()] == 0, "Already registered");
        playerCount += 1;
        uint256 team = playerCount % teamCount;
        playerTeam[_msgSender()] = uint8(team);
        playerLocation[_msgSender()] = uint16(team);

        IForwardRequest.NFT memory nft = _msgNFT();

        emit Registered(_msgSender(), nft.contractAddress, nft.tokenId);
    }

    function currentRound() public view returns (uint8) {
        uint256 elapsed = block.timestamp - gameStart;

        return uint8((elapsed / (teamCount * turnLength)) + 1);
    }

    function currentRoundStart() public view returns (uint256) {
        return gameStart + (currentRound() - 1) * teamCount * turnLength;
    }

    function currentTeamMove() public view returns (uint256) {
        uint256 roundStart = gameStart + (turnLength * teamCount * (currentRound() - 1));
        uint256 elapsedRound = block.timestamp - roundStart;

        return (elapsedRound / turnLength) + 1;
    }

    function playersPerTeam(uint8 team) public view returns (uint256 count) {
        uint256 min = playerCount / teamCount;
        uint256 mod = playerCount % teamCount;

        count = min + (mod > (team - 1) ? 1 : 0);
    }

    function performMove(uint16 targetSpace) external onlyForwarder {
        // TODO: would a merkle tree be better here for list of valid adjacent spaces?
        // The max adjacent spaces will prob be < 10, not a crazy loop
        //
        address player = _msgSender();
        require(playerTeam[player] == currentTeamMove(), "Not your team's turn");
        require(playerLastMove[player] < currentRoundStart(), "Move alrready taken this round");

        uint16 currentSpace = playerLocation[player];
        uint256 availableSpaceCount = adjacentSpaces[currentSpace].length;

        bool validMove;
        for (uint256 index = 0; index < availableSpaceCount; ) {
            if (adjacentSpaces[currentSpace][index] == targetSpace) {
                validMove = true;
                break;
            }
            unchecked {
                ++index;
            }
        }

        require(validMove == true, "Ivalid Move");

        playerLastMove[player] = block.timestamp;
        playerLocation[player] = targetSpace;
        
        uint16 controllingTeam = controlledSpaces[targetSpace];

        if (controllingTeam == 0) {
            controlledSpaces[targetSpace] = playerTeam[player];
        } else if (controllingTeam != playerTeam[player] && controllingTeam <= teamCount) {
            // attackers cant move again?
            roundBattleSpaces[currentRound()].push(targetSpace);
            controlledSpaces[targetSpace] = teamCount + 1;
        }

        emit Moved(player, targetSpace);
    }

    function performBattle(uint16 battleSpace) internal {}
}
