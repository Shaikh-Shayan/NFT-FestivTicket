// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FestivalERC is ERC1155, ERC1155Supply {
    /**
    @variable: _tokenIds -> To keep the record of the total number of tokens minted from this contract.
               Counter library is used to increase the vairable efficiently. 
     */
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    /**
     variable: _uris -> This mapping will help to retrive the URI by using the Token IDs. 
     */
    mapping(uint256 => string) public _uris;

    /**
    variable: Market -> This struct stores the information of markets that use this contract.
              currencyTokenId -> These are ERC20 tokens that will be used to purchase ticket NFTs in the marketplace.
              nftId -> These are the ERC721 tokens that are tickets and will be purchased from currencyToken.
              registerd -> If the market is registered on this contract.
     */
    struct Market {
        string marketKey; // Unique string that represent a market.
        address addr; // Contract address of the Marketplace.
        uint256 currencyTokenId;
        string currencyTokenUri;
        uint256 nftId;
        string nftUri;
        bool registered;
    }

    /**
    variable: _marketKeyToMarket -> Mapping of market infromation with the unique market key.
     */
    mapping(string => Market) public _marketKeyToMarket;

    // event when a new market is added
    event MarketAdded(
        string indexed marketKey,
        address indexed addr,
        uint256 currencyTokenId,
        string currencyTokenUri,
        uint256 nftId,
        string nftUri
    );

    // event when Collectible is minted to a user via a market
    event CollectibleMinted(
        string indexed marketKey,
        uint256 indexed tokenId,
        uint256 indexed quantity,
        string tokenURI,
        address to
    );

    // event when Currency is minted to a market, for a market, via market.
    event CurrencyMinted(
        string indexed marketKey,
        uint256 indexed tokenId,
        uint256 indexed supply,
        string tokenURI
    );

    constructor(string memory uri_) ERC1155(uri_) {}

    /**
    @dev For registration of the of the new markets. This will create a new market entry in the memeory.
    
    @param marketKey Unique market key string
    @param addr Marketplace address
    @param currencyTokenUri Info of currency tokens. 
    @param nftUri Info of Ticket NFT

    @return currencyTokenId 
    @return nftId
     */
    function addMarket(
        string calldata marketKey,
        address addr,
        string calldata currencyTokenUri,
        string calldata nftUri
    ) public returns (uint256 currencyTokenId, uint256 nftId) {
        require(
            msg.sender == addr,
            "msg.sender should be the market address itself!"
        );
        _tokenIds.increment(); // 0 -> 1
        currencyTokenId = _tokenIds.current();
        _tokenIds.increment(); // 1 -> 2
        nftId = _tokenIds.current();
        _uris[currencyTokenId] = currencyTokenUri;
        _uris[nftId] = nftUri;
        Market memory market = Market(
            marketKey,
            addr,
            currencyTokenId,
            currencyTokenUri,
            nftId,
            nftUri,
            true
        );
        _marketKeyToMarket[marketKey] = market;
        emit MarketAdded(
            marketKey,
            addr,
            currencyTokenId,
            currencyTokenUri,
            nftId,
            nftUri
        );
        return (currencyTokenId, nftId);
    }

    /**
    @dev To override the inhertence.
    @param tokenId See variables.
    @return _uris URI of a token.  
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _uris[tokenId];
    }

    /**
    @dev Mints the NFT on an address requested by the contract.
    @param to Public address of the reciever.
     */
    function mintCollectible(
        string calldata marketKey,
        uint256 quantity,
        address to
    ) public {
        require(
            _marketKeyToMarket[marketKey].registered == true,
            "Add market first!"
        );
        require(
            msg.sender == _marketKeyToMarket[marketKey].addr,
            "Only market contract can mint NFTs!"
        );
        uint256 nftId = _marketKeyToMarket[marketKey].nftId;
        string memory nftUri = _marketKeyToMarket[marketKey].nftUri;
        _mint(to, nftId, quantity, "");
        emit CollectibleMinted(marketKey, nftId, quantity, nftUri, to);
    }

    /**
    @dev Mints the currency to the smart contract itself so that users can buy directly from Marketplace.
     */
    function mintCurrency(string calldata marketKey, uint256 supply) public {
        require(
            _marketKeyToMarket[marketKey].registered == true,
            "Add market first!"
        );
        require(
            msg.sender == _marketKeyToMarket[marketKey].addr,
            "Only market contract can mint Currency!"
        );
        uint256 currencyTokenId = _marketKeyToMarket[marketKey].currencyTokenId;
        string memory currencyTokenUri = _marketKeyToMarket[marketKey]
            .currencyTokenUri;
        _mint(msg.sender, currencyTokenId, supply, "");
        emit CurrencyMinted(
            marketKey,
            currencyTokenId,
            supply,
            currencyTokenUri
        );
    }

    // Derived contract must override function "_beforeTokenTransfer".
    // Two or more base classes define function with same name and parameter types.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
