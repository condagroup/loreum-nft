// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

contract Blackhat {

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_updateMintCost(address NFT, uint256 amount) external returns (bool ok) {
        string memory sig = "updateMintCost(uint256)";
        (ok,) = address(NFT).call(abi.encodeWithSignature(sig, amount));
    }

    function try_transferOwnership(address NFT, address newOwner) external returns (bool ok) {
        string memory sig = "transferOwnership(address)";
        (ok,) = address(NFT).call(abi.encodeWithSignature(sig, newOwner));
    }

    function try_publicMint(address NFT, uint8 amount, uint mintCost) external returns (bool ok) {
        string memory sig = "publicMint(uint8)";
        (ok,) = address(NFT).call{value: amount * mintCost}(abi.encodeWithSignature(sig, amount));
    }

}