// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FestivalNFT is ERC1155, ERC1155Supply {
    /**
    @variables:

    Counters -> To keep the track of ticket ids.
    _uris -> Retrive the URIs of throught ticket IDs.

     */
    using Counters for Counters.Counter;
    Counters.Counter public _ticketIds;
    mapping(uint256 => string) public _uris;

    /**
    Market -> This struct will store all the new Fests that are listed on the market place. 
              The Market key will be a unique string for every new fest.
     */
    struct Market {
        string marketKey;
        address addr;
        uint256 currencyTicketId;
        string currencyTicketUri;
        bool registered;
    }

    /**
    Name of the Fest -> Information of the market.
     */
    mapping(string => Market) public _marketKeyToMarket;

    /**
    This event will be fired when a new Fest is created and listed on the market.
     */

    event MarketAdded(
        string indexed marketKey,
        address indexed addr,
        uint256 currencyTicketId,
        string currencyTicketUri
    );

    /**
    This event will be fired when New currency ticket are minted for the fest after it is added to the market.
     */
    event CurrencyMinted(
        string indexed marketKey,
        uint256 indexed ticketId,
        uint256 indexed supply,
        string ticketURI
    );

    constructor(string memory uri_) ERC1155(uri_) {}

    /**
    dev -> To add a new fest in this contract.
    arguments -> 1. Unique market key.
                 2. Market place address.
                 3. Ticket URI.
     */
    function addMarket(
        string calldata marketKey,
        address addr,
        string calldata currencyTicketUri
    ) public returns (uint256 currencyTicketId) {
        require(
            msg.sender == addr,
            "msg.sender should be the market address itself!"
        );
        _ticketIds.increment(); // 0 -> 1
        currencyTicketId = _ticketIds.current();

        _uris[currencyTicketId] = currencyTicketUri;

        Market memory market = Market(
            marketKey,
            addr,
            currencyTicketId,
            currencyTicketUri,
            true
        );

        _marketKeyToMarket[marketKey] = market;
        emit MarketAdded(marketKey, addr, currencyTicketId, currencyTicketUri);
        return (currencyTicketId);
    }

    /**
    dev -> retrive the uri of against the tickedID.
    argument -> ticket id (recieved from addMarket: currencyTicketId)
     */

    function uri(uint256 ticketId)
        public
        view
        override
        returns (string memory)
    {
        return _uris[ticketId];
    }

    /**
    dev -> Mints currency tickets for a registered fest.
    arguments -> 1. Name of the fest. 
                 2. NUmber of tokens to be minted to marketplace.
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
        uint256 currencyTicketId = _marketKeyToMarket[marketKey]
            .currencyTicketId;
        string memory currencyTicketUri = _marketKeyToMarket[marketKey]
            .currencyTicketUri;
        _mint(msg.sender, currencyTicketId, supply, "");
        emit CurrencyMinted(
            marketKey,
            currencyTicketId,
            supply,
            currencyTicketUri
        );
    }

    /**
    dev -> Internal function.
     */
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
