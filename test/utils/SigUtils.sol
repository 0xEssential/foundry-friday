// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IForwardRequest} from "essential-contracts/contracts/fwd/IForwardRequest.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    bytes32 public constant ERC721_TYPEHASH =
        keccak256(
            "ForwardRequest(address to,address from,address authorizer,address nftContract,uint256 nonce,uint256 nftChainId,uint256 nftTokenId,uint256 targetChainId,bytes data)"
        );

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(IForwardRequest.ERC721ForwardRequest memory req)
        public
        view
        returns (bytes32)
    {
        return ECDSA.toTypedDataHash(
            DOMAIN_SEPARATOR, 
            keccak256(
                abi.encode(
                    ERC721_TYPEHASH,
                    req.to,
                    req.from,
                    req.authorizer,
                    req.nftContract,
                    req.nonce,
                    req.nftChainId,
                    req.nftTokenId,
                    req.targetChainId,
                    keccak256(req.data)
                )
            )
        );
    }
}
