// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "essential-contracts/contracts/fwd/EssentialERC2771Context.sol";

contract AnOnchainGame is EssentialERC2771Context {
  // Constants
  uint256 public constant teamCount = 3;

  // Storage
  uint256 public playerCount;
  mapping(address => uint8) public playerTeam;

  // Events
  event Registered(address indexed player, address nftContract, uint256 nftTokenId);


  constructor(address trustedForwarder) EssentialERC2771Context(trustedForwarder) {}

  function register() external onlyForwarder {
    playerCount += 1;
    uint256 team = playerCount % teamCount;
    playerTeam[_msgSender()] = uint8(team);

    IForwardRequest.NFT memory nft = _msgNFT();

    emit Registered(_msgSender(), nft.contractAddress, nft.tokenId);
  }

  function playersPerTeam(uint8 team) public view returns (uint256 count){
    uint256 min = playerCount / teamCount;
    uint256 mod = playerCount % teamCount;
    
    count = min + (mod > (team - 1) ? 1 : 0);
  }
}
