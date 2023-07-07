// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Minter is ERC721Holder {

    /// @notice Handles arbitrary call() executions to address(this).
    fallback() external payable { }

    /// @notice Handles arbitrary direct ETH transfers.
    receive() external payable { }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_publicMint(address NFT, uint8 amount, uint mintCost) external returns (bool ok) {
        string memory sig = "publicMint(uint8)";
        (ok,) = address(NFT).call{value: amount * mintCost}(abi.encodeWithSignature(sig, amount));
    }

}