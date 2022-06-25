// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SigUtils} from "./utils/SigUtils.sol";
import {EssentialForwarder} from "essential-contracts/contracts/fwd/EssentialForwarder.sol";
import {IForwardRequest} from "essential-contracts/contracts/fwd/IForwardRequest.sol";
import {AnOnchainGame} from "../src/AnOnchainGame.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "forge-std/console.sol";


contract AnOnchainGameTest is Test {
    using ECDSA for bytes32;

    EssentialForwarder internal forwarder;
    SigUtils internal sigUtils;
    AnOnchainGame internal gameContract;

    uint256 internal playerPrivateKey;
    address internal player;

    uint256 internal ownershipSignerPrivateKey;
    address internal ownershipSigner;

    function setUp() public {
        string[] memory urls;
        
        forwarder = new EssentialForwarder("EssentialForwarder", urls);
        sigUtils = new SigUtils(forwarder._domainSeparatorV4());
        gameContract = new AnOnchainGame(address(forwarder));

        playerPrivateKey = 0xC11CE;
        player = vm.addr(playerPrivateKey);

        ownershipSignerPrivateKey = 0xB12CE;
        ownershipSigner = vm.addr(ownershipSignerPrivateKey);

        forwarder.setOwnershipSigner(ownershipSigner);
    }

    // helper for building request struct
    function buildRequest(bytes memory selector) 
        internal 
        view 
        returns (IForwardRequest.ERC721ForwardRequest memory) {
            return IForwardRequest.ERC721ForwardRequest({
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
                data: selector
            });
    }

    // helper for signing request struct
    function signRequest(IForwardRequest.ERC721ForwardRequest memory request) 
        internal  
        returns (bytes memory) {
            bytes32 digest = sigUtils.getTypedDataHash(request);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPrivateKey, digest);
            return abi.encodePacked(r, s, v);
    }

    // helper for mocking REST API for signing ownership
    function mockOwnershipSig(IForwardRequest.ERC721ForwardRequest memory request) 
        internal  
        returns (bytes memory) {
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
        return abi.encodePacked(rMock, sMock, vMock);
    }

    // We use EIP-3668 OffchainLookup for trust-minimized cross-chain token gating.
    // The forwarding contract will revert with an OffchainLookup error in the 
    // "happy path" - the revert is expected and has params we may want to assert
    function testFailRegister() public {
        IForwardRequest.ERC721ForwardRequest memory request = buildRequest(
            abi.encode(keccak256("register()"))
        );

        bytes memory sig = signRequest(request);

        vm.expectRevert(EssentialForwarder.OffchainLookup.selector);
        
        forwarder.preflight(request, sig);
    }

    // If we know that EssentialForwarder#preflight reverts with OffchainLookup,
    // we can unit test EssentialForwarder#executeWithProof by mocking out the
    // signature that our API would normally provide. 
    function testTrustedRegister() public {
        IForwardRequest.ERC721ForwardRequest memory request = buildRequest(
            abi.encode(keccak256("register()"))
        );

        bytes memory userSignature = signRequest(request);
        bytes memory extraData = abi.encode(block.timestamp, request, userSignature);
        bytes memory response = mockOwnershipSig(request);

        forwarder.executeWithProof(response, extraData);
    }

    function testTrustedRegisterPlayerCount() public {
        IForwardRequest.ERC721ForwardRequest memory request = buildRequest(
            abi.encode(keccak256("register()"))
        );

        bytes memory userSignature = signRequest(request);
        bytes memory extraData = abi.encode(block.timestamp, request, userSignature);
        bytes memory response = mockOwnershipSig(request);

        forwarder.executeWithProof(response, extraData);
        
        uint256 playerCount = gameContract.playerCount();
        assertEq(playerCount, 1);
    }

    function testTrustedRegisterTeamAssignment() public {
        IForwardRequest.ERC721ForwardRequest memory request = buildRequest(
            abi.encode(keccak256("register()"))
        );

        bytes memory userSignature = signRequest(request);
        bytes memory extraData = abi.encode(block.timestamp, request, userSignature);
        bytes memory response = mockOwnershipSig(request);

        forwarder.executeWithProof(response, extraData);

        uint256 count = gameContract.playersPerTeam(1);
        assertEq(count, 1);

        uint8 team = gameContract.playerTeam(player);
        assertEq(team, 1);
    }
}
