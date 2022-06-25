// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "essential-contracts/contracts/fwd/EssentialERC2771Context.sol";

contract Risk is EssentialERC2771Context {
  // Storage
  uint256 internal playerCount;
  mapping(address => uint8) public playerTeam;

  // Events
  event Registered(address indexed player, address nftContract, uint256 nftTokenId);


  constructor(address trustedForwarder) EssentialERC2771Context(trustedForwarder) {}

  function register() external onlyForwarder {
    playerCount += 1;
    uint256 team = playerCount % 3;
    playerTeam[_msgSender()] = uint8(team);

    IForwardRequest.NFT memory nft = _msgNFT();

    emit Registered(_msgSender(), nft.contractAddress, nft.tokenId);
  }

  function playersPerTeam(uint8 team) public view returns (uint256 count){
    uint256 min = playerCount / 3;
    uint256 mod = playerCount % 3;
    
    count = min + (mod < team ? 1 : 0);
  }
}
