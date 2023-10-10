// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ERC721Facet.sol";
import "./helpers/DiamondUtils.sol";
import "../contracts/facets/MarketPlaceFacet.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    TokenFacet tkFacet;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            "Magnusen",
            "MAG"
        );
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        tkFacet = new TokenFacet(18);

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(tkFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("TokenFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testOwnerCannotCreateListing() public {
        l.lister = userB;
        switchSigner(userB);

        vm.expectRevert(ERC721Marketplace.NotOwner.selector);
        mPlace.createListing(l);
    }

    function testNonApprovedNFT() public {
        switchSigner(userA);
        vm.expectRevert(ERC721Marketplace.NotApproved.selector);
        mPlace.createListing(l);
    }

    function testMinPriceTooLow() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.price = 0;
        vm.expectRevert(ERC721Marketplace.MinPriceTooLow.selector);
        mPlace.createListing(l);
    }

    function testMinDeadline() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        vm.expectRevert(ERC721Marketplace.DeadlineTooSoon.selector);
        mPlace.createListing(l);
    }

    function testMinDuration() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(ERC721Marketplace.MinDurationNotMet.selector);
        mPlace.createListing(l);
    }

    function testValidSig() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyB
        );
        vm.expectRevert(ERC721Marketplace.InvalidSignature.selector);
        mPlace.createListing(l);
    }

    // EDIT LISTING
    function testEditNonValidListing() public {
        switchSigner(userA);
        vm.expectRevert(ERC721Marketplace.ListingNotExistent.selector);
        mPlace.editListing(1, 0, false);
    }

    function testEditListingNotOwner() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyA
        );
        // vm.expectRevert(Marketplace.ListingNotExistent.selector);
        uint256 lId = mPlace.createListing(l);

        switchSigner(userB);
        vm.expectRevert(ERC721Marketplace.NotOwner.selector);
        mPlace.editListing(lId, 0, false);
    }

    function testEditListing() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyA
        );
        uint256 lId = mPlace.createListing(l);
        mPlace.editListing(lId, 0.01 ether, false);

        ERC721Marketplace.Listing memory t = mPlace.getListing(lId);
        assertEq(t.price, 0.01 ether);
        assertEq(t.active, false);
    }

    // EXECUTE LISTING
    function testExecuteNonValidListing() public {
        switchSigner(userA);
        vm.expectRevert(ERC721Marketplace.ListingNotExistent.selector);
        mPlace.executeListing(1);
    }

    function testExecuteExpiredListing() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
    }

    function testExecuteListingNotActive() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyA
        );
        uint256 lId = mPlace.createListing(l);
        mPlace.editListing(lId, 0.01 ether, false);
        switchSigner(userB);
        vm.expectRevert(ERC721Marketplace.ListingNotActive.selector);
        mPlace.executeListing(lId);
    }

    function testExecutePriceNotMet() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyA
        );
        uint256 lId = mPlace.createListing(l);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721Marketplace.PriceNotMet.selector,
                l.price - 0.9 ether
            )
        );
        mPlace.executeListing{value: 0.9 ether}(lId);
    }

    function testExecutePriceMismatch() public {
        switchSigner(userA);
        nft.setApprovalForAll(address(mPlace), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyA
        );
        uint256 lId = mPlace.createListing(l);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721Marketplace.PriceMismatch.selector,
                l.price
            )
        );
        mPlace.executeListing{value: 1.1 ether}(lId);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
