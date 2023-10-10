// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/TokenFacet.sol";
import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    TokenFacet tkFacet;

    function  setUp() public {
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

    function testName() public{
        assertEq(TokenFacet(address(diamond)).name(), "Magnusen");
    }

    function testSymbol() public {
        assertEq(TokenFacet(address(diamond)).symbol(), "MAG");
    }

    function testTransfer() public {
        vm.startPrank(address(0x2222));
        TokenFacet(address(diamond)).mint(address(0x2222), 10000e18);
        //transfer to address 3
        TokenFacet(address(diamond)).transfer(address(0x3333), 100e18);

        // Assert Balance of address 2
        assertEq(TokenFacet(address(diamond)).balanceOf(address(0x2222)), 9900e18);
        // Assert balance of address 3
        assertEq(TokenFacet(address(diamond)).balanceOf(address(0x3333)), 100e18);
    }

    function testTotalSupply() public {
        vm.startPrank(address(0x2222));
        TokenFacet(address(diamond)).mint(address(0x2222), 10000e18);
        assertEq(TokenFacet(address(diamond)).totalSupply(address(0x2222)), 10000e18);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}