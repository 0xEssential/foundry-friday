// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SigUtils} from "./utils/SigUtils.sol";
import {EssentialForwarder} from "essential-contracts/contracts/fwd/EssentialForwarder.sol";
import {IForwardRequest} from "essential-contracts/contracts/fwd/IForwardRequest.sol";
import {Risk} from "../src/Risk.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "forge-std/console.sol";


contract RiskTest is Test {
    using ECDSA for bytes32;

    EssentialForwarder internal forwarder;
    SigUtils internal sigUtils;
    Risk internal gameContract;

    uint256 internal deployerPrivateKey;
    address internal deployer;

    uint256 internal playerPrivateKey;
    address internal player;

    uint256 internal ownershipSignerPrivateKey;
    address internal ownershipSigner;

    function setUp() public {
        string[] memory urls;
        
        forwarder = new EssentialForwarder("EssentialForwarder", urls);
        sigUtils = new SigUtils(forwarder._domainSeparatorV4());
        gameContract = new Risk(address(forwarder));

        deployerPrivateKey = 0xA11CE;
        deployer = vm.addr(deployerPrivateKey);

        playerPrivateKey = 0xC11CE;
        player = vm.addr(playerPrivateKey);

        ownershipSignerPrivateKey = 0xB12CE;
        ownershipSigner = vm.addr(ownershipSignerPrivateKey);

        forwarder.setOwnershipSigner(ownershipSigner);
    }

    function testExample() public {
        assertTrue(true);
    }

    function testPlayersPerTeam() public {
        uint256 count = gameContract.playersPerTeam(0);
        assertEq(count, 0);
    }

    // We use EIP-3668 OffchainLookup for trust-minimized cross-chain token gating.
    // The forwarding contract will revert with an OffchainLookup error in the 
    // "happy path" - the revert is expected and has params we may want to assert
    function testFailRegister() public {
        IForwardRequest.ERC721ForwardRequest memory request = IForwardRequest.ERC721ForwardRequest({
            to: address(gameContract),
            from: player,
            authorizer: player,
            nftContract: player,
            nonce: 0,
            nftChainId: block.chainid,
            nftTokenId: 1,
            targetChainId: block.chainid,
            value: 0,
            gas: 1e6,
            data: abi.encode(keccak256("register()"))
        });

        bytes32 digest = sigUtils.getTypedDataHash(request);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);

        vm.expectRevert(EssentialForwarder.OffchainLookup.selector);
        
        forwarder.preflight(request, abi.encodePacked(r, s, v));
    }

    // If we know that EssentialForwarder#preflight reverts with OffchainLookup,
    // we can unit test EssentialForwarder#executeWithProof by mocking out the
    // signature that our API would normally provide. 
    function testTrustedRegister() public {
        IForwardRequest.ERC721ForwardRequest memory request = IForwardRequest.ERC721ForwardRequest({
            to: address(gameContract),
            from: player,
            authorizer: player,
            nftContract: player,
            nonce: 0,
            nftChainId: block.chainid,
            nftTokenId: 1,
            targetChainId: block.chainid,
            value: 0,
            gas: 1e6,
            data: abi.encode(keccak256("register()"))
        });

        bytes32 digest = sigUtils.getTypedDataHash(request);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPrivateKey, digest);
        bytes memory userSignature = abi.encodePacked(r, s, v);
        bytes memory extraData = abi.encode(block.timestamp, request, userSignature);

        // ownership API mock
        bytes32 message = forwarder.createMessage(
            request.from,
            request.authorizer,
            request.nonce,
            request.nftChainId,
            request.nftContract,
            request.nftTokenId,
            block.timestamp
        ).toEthSignedMessageHash();

        (uint8 vMock, bytes32 rMock, bytes32 sMock) = vm.sign(ownershipSignerPrivateKey, message);
        bytes memory response = abi.encodePacked(rMock, sMock, vMock);

        forwarder.executeWithProof(response, extraData);
    }

}
