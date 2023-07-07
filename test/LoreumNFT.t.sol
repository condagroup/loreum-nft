// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

// Utility import
import "test/utilities/Utility.sol";
import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

// NFT contract import(s)
import "src/LoreumNFT.sol";
 
contract LoreumNFTTest is Utility, ERC721Holder {

    LoreumNFT NFT;

    // Initial NFT settings
    string public name = "LoreumNFT";
    string public symbol = "LOREUM";
    string public tokenUri = "ipfs://bafybeia4ba2mxk3dzdhu2kaqeh5svu244qmcwbkhm56e2nz4pnuqfake4q/";

    uint public mintCost = 0.05 ether;
    uint96 public royaltyFraction = 500;  // 5%
    uint16 public maxSupply = 10000;
    uint8 public maxMint = 5;

    address admin;      /// @dev Defined in the setUp() function



    // Initial setUp() function, runs before every test_*.
    function setUp() public {
        
        // Create actors and tokens
        deployCore();
        
        // Fund "tom" for minting expenses
        payable(address(tom)).transfer(100 ether);

        // We define this variable here after deployCore() in order to instantiate the actor "god"
        admin = address(god);

        NFT = new LoreumNFT(
            name, 
            symbol,
            tokenUri,
            mintCost,
            royaltyFraction,
            maxSupply,
            maxMint,
            admin
        );

    }

    function test_LoreumNFT_initial_state(uint128 salePrice) public {

        // Initial constructor() parameters
        assertEq(NFT.name(), name);
        assertEq(NFT.symbol(), symbol);
        assertEq(NFT.tokenUri(), "ipfs://bafybeia4ba2mxk3dzdhu2kaqeh5svu244qmcwbkhm56e2nz4pnuqfake4q/");
        assertEq(NFT.MAX_SUPPLY(), maxSupply);
        assertEq(NFT.MAX_MINT(), maxMint);
        assertEq(NFT.owner(), admin);
        assertEq(NFT.mintCost(), 0.05 ether);

        // ERC721
        assertEq(NFT.balanceOf(address(this)), 0);
        
        // ERC721Enumerable
        assertEq(NFT.totalSupply(), 0);

        // ERC2981
        uint256 compressedSalePrice = uint256(salePrice);   // NOTE: Using uint128 compressed range to avoid overflow.
        (address royaltyReceiver, uint256 feeAmount) = NFT.royaltyInfo(0, compressedSalePrice);
        assertEq(royaltyReceiver, NFT.owner());
        assertEq(feeAmount, compressedSalePrice * royaltyFraction / 10_000);

        // ERC165Storage
        assert(NFT.supportsInterface(type(IERC721).interfaceId));
        assert(NFT.supportsInterface(type(IERC721Metadata).interfaceId));
        assert(NFT.supportsInterface(type(IERC721Enumerable).interfaceId));
        assert(NFT.supportsInterface(type(IERC2981).interfaceId));
    }
    


    // ~
    // Loreum.nft Override Function Testing
    // ~

    function test_tokenURI_view(uint16 _uri) public {
        assertEq(NFT.tokenURI(_uri), string(abi.encodePacked(NFT.tokenUri(), Strings.toString(_uri))));
    }

    function test_transferOwnership_state() public {
        
        address newOwner = address(42);

        // transferOwnership()
        assert(god.try_transferOwnership(address(NFT), newOwner));

        // Post-state
        assertEq(NFT.owner(), newOwner);
        (address royaltyReceiver, ) = NFT.royaltyInfo(0, 1 ether);
        assertEq(royaltyReceiver, newOwner);

    }

    function test_transferOwnership_restrictions() public {

        // onlyOwner
        assert(!ass.try_transferOwnership(address(NFT), address(ass)));

        // newOwner != address(0)
        assert(!god.try_transferOwnership(address(NFT), address(0)));
    }



    // ~
    // Loreum.nft Native Function Testing
    // ~
    
    function test_updateMintCost_state_changes(uint256 newCost) public {

        // updateMintCost()
        assert(god.try_updateMintCost(address(NFT), newCost));

        // Post-state
        assertEq(NFT.mintCost(), newCost);
    }

    function test_updateMintCost_restrictions(uint256 newCost) public {
        assert(!ass.try_updateMintCost(address(NFT), newCost));
    }

    function test_publicMint_state(uint8 amountToMint) public {

        uint8 mintThisMuch = amountToMint % 5 + 1;

        // Pre-state
        uint preBalanceMinter = address(tom).balance;
        uint preBalanceOwner = address(NFT.owner()).balance;

        // publicMint()
        assert(tom.try_publicMint(address(NFT), mintThisMuch, NFT.mintCost()));

        // Post-state
        uint postBalanceMinter = address(tom).balance;
        uint postBalanceOwner = address(NFT.owner()).balance;

        assertEq(preBalanceMinter - postBalanceMinter, NFT.mintCost() * mintThisMuch);
        assertEq(postBalanceOwner - preBalanceOwner, NFT.mintCost() * mintThisMuch);
        assertEq(NFT.totalSupply(), mintThisMuch);
        assertEq(NFT.balanceOf(address(tom)), mintThisMuch);

        for (uint8 b = 0; b < mintThisMuch; b++) {
            assertEq(NFT.ownerOf(b + 1), address(tom));
        }

        // TODO: Consider any ERC721Enumerable _beforeTokenTransfer() / _afterTokenTransfer() state changes
    }

    function test_publicMint_restrictions() public {
        
        // User attempts to pay less than mintCost()
        // LoreumNFT::publicMint() msg.value != amount * mintCost
        uint256 payment = NFT.mintCost() - 0.01 ether;
        assert(!ass.try_publicMint(address(NFT), 1, payment));

        // User attempts to mint 0 NFTs
        // LoreumNFT::publicMint() amount == 0
        payment = NFT.mintCost() - 0.01 ether;
        assert(!ass.try_publicMint(address(NFT), 0, payment));
        
        // User attempts to mint more than MAX_MINT
        // LoreumNFT::publicMint() amount + totalMinted[_msgSender()] > MAX_MINT
        payment = NFT.mintCost() * (NFT.MAX_MINT() + 1);
        assert(!ass.try_publicMint(address(NFT), NFT.MAX_MINT() + 1, payment));
    }

    function test_publicMint_state_full() public {


        // NOTE: type(uint160) required for address(uint160) typecasting below
        uint160 addressID = 55;

        address payable minter = payable(address(addressID));
        minter.transfer(NFT.MAX_MINT() * NFT.mintCost());

        // Pre-state
        uint256 preBal = NFT.owner().balance;

        // Conduct "Mint"
        while(NFT.totalSupply() < NFT.MAX_SUPPLY()) {
            if (NFT.balanceOf(minter) == NFT.MAX_MINT()) {
                // minter = address(addressID++);
                addressID++;
                minter = payable(address(addressID));
                minter.transfer(NFT.MAX_MINT() * NFT.mintCost());
            }
            hevm.startPrank(minter);
            // NOTE: This test will revert if NFT.MAX_SUPPLY() % NFT.MAX_MINT != 0
            NFT.publicMint{value: NFT.mintCost() * NFT.MAX_MINT()}(NFT.MAX_MINT());
            hevm.stopPrank();
        }

        // Post-state

        // NFT "Mint" concludes when totalSupply() == MAX_SUPPLY()
        assertEq(NFT.totalSupply(), NFT.MAX_SUPPLY());
        assertEq(NFT.owner().balance, preBal + (NFT.totalSupply() * NFT.mintCost()));

        // Tom (or any minter) is unable to mint additional
        // LoreumNFT::publicMint() minted >= MAX_SUPPLY || minted + amount > MAX_SUPPLY
        assert(!tom.try_publicMint(address(NFT), 1, NFT.mintCost()));

        // TODO: Check minted + amount > MAX_SUPPLY (i.e. 9999 minted, and mintAmount == 2)!
    }

    function test_publicMint_state_full2() public {


        // NOTE: type(uint160) required for address(uint160) typecasting below
        uint160 addressID = 55;

        address payable minter = payable(address(addressID));
        minter.transfer(NFT.MAX_MINT() * NFT.mintCost());

        // Conduct "Mint"
        while(NFT.totalSupply() < NFT.MAX_SUPPLY() - 6) {
            if (NFT.balanceOf(minter) == NFT.MAX_MINT()) {
                // minter = address(addressID++);
                addressID++;
                minter = payable(address(addressID));
                minter.transfer(NFT.MAX_MINT() * NFT.mintCost());
            }
            hevm.startPrank(minter);
            // NOTE: This test will revert if NFT.MAX_SUPPLY() % NFT.MAX_MINT != 0
            NFT.publicMint{value: NFT.mintCost() * NFT.MAX_MINT()}(NFT.MAX_MINT());
            hevm.stopPrank();
        }



        // Assert there's 9995 total minted, and mint 4 more to push it to edge-case 9999.
        NFT.publicMint{value: NFT.mintCost() * 4}(4);
        assertEq(NFT.totalSupply(), 9999);
        
        // Assert "tom" can finish the mint by minting only 1 more.
        assert(!tom.try_publicMint(address(NFT), 5, NFT.mintCost()));
        assert(!tom.try_publicMint(address(NFT), 4, NFT.mintCost()));
        assert(!tom.try_publicMint(address(NFT), 3, NFT.mintCost()));
        assert(!tom.try_publicMint(address(NFT), 2, NFT.mintCost()));
        assert(tom.try_publicMint(address(NFT), 1, NFT.mintCost()));

    }

}
