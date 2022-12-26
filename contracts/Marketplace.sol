// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./FestivalERC.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/*
- There are maximum 1000 tickets
- You can buy tickets from the organizer at a fixed price in the currency token
- You can buy for and sell tickets to others, but the price can never be higher than 110% of the previous sale
- Add a monetization option for the organizer in the secondary market sales
 */
contract FestMarket is ReentrancyGuard {
    /**
    varaible: _organizer -> Public address of the Fest organizer.
     */
    address payable public _organizer;

    /**
    variable: _festivalERC -> Instance of ERC1155 Smart Contract.
     */
    FestivalERC public _festivalERC;

    /**
    variable: _currencyTokenId -> Currency token ID from ERC contract.
     */
    uint256 public _currencyTokenId;

    // currency token price in ether(usd later todo)
    uint256 public _currencyTokenWeiPrice = 0.1 ether; // in wei per token

    // fest ticket NFT token id
    uint256 public _nftId;

    // fest ticket NFT price
    uint256 public _nftWeiPrice = 1 ether; // 1 CurrencyToken, in wei

    // monetization
    uint256 public _listingPrice = 0.025 ether; // in wei

    // keeps the count for our sold tickets // max 1000
    uint256 public _ticketsSold = 0;

    // NOTE: extra logic of secondary market
    using Counters for Counters.Counter;
    Counters.Counter public _ticketIds; // tickets listed in secondary market
    mapping(address => mapping(uint256 => uint256)) public _lastSalePrice; // EOA -> (TokenId -> LastSold)
    mapping(uint256 => FestTicket) public _ticketIdTtoFestTicket; // ticketId -> FestTicket

    struct FestTicket {
        uint256 ticketId;
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 priceWeiToken;
        bool sold;
    }

    event FestTicketDirectSold(
        string marketKey,
        address payable owner,
        uint256 priceWeiToken,
        uint256 quantity
    );

    event FestTicketListed(
        uint256 ticketId,
        uint256 tokenId,
        address payable owner,
        address payable seller,
        uint256 priceWeiToken,
        bool sold
    );

    event FestTicketSold(
        uint256 ticketId,
        uint256 tokenId,
        address payable owner,
        address payable seller,
        uint256 priceWeiToken,
        bool sold
    );

    /**
    @dev Set the organizer, Initialize FestivalERC contract, Adds a default market to festivalERC.
    For now we are using default URIs
     */

    constructor(address festivalERC) {
        _organizer = payable(msg.sender);
        _festivalERC = FestivalERC(festivalERC);
        // register market in festivalERC first
        (uint256 currencyTokenId, uint256 nftId) = _festivalERC.addMarket(
            "settlemint_fest",
            address(this),
            "settlemint_fest_currency_token_uri",
            "settlemint_fest_nft_uri"
        );
        _currencyTokenId = currencyTokenId;
        _nftId = nftId;
    }

    /**
    @dev Mints the currency tokens from festivalERC contract to this marketplace.
    @param supplyInToken Total supply to be minted.
     */
    function mintCurrencyToken(uint256 supplyInToken) public {
        require(msg.sender == _organizer, "Only organizer can mint currency!");
        _festivalERC.mintCurrency("settlemint_fest", supplyInToken * 10**18);
    }

    /**
    @dev Tansaction of currency token to the sender against eth.
     */
    function buyCurrencyToken(uint256 quantityWeiToken) public payable {
        require(
            msg.value == (_currencyTokenWeiPrice * quantityWeiToken) / (10**18),
            "Please send the correct eth in order to complete the purchase!"
        );
        // send currency token from market contract to msg.sender
        _festivalERC.safeTransferFrom(
            address(this),
            msg.sender,
            _currencyTokenId,
            quantityWeiToken,
            ""
        );
        // monetization for _organizer
        payable(_organizer).transfer(msg.value);
    }

    /**
    @dev Facilitates transaction of Ticket NFT against currency from ERC1155 contract.
     */
    function buyFestTicket(uint256 quantity) public {
        require(
            _festivalERC.totalSupply(_nftId) != 1000,
            "All tickets sold! :("
        );
        require(
            _festivalERC.totalSupply(_nftId) + quantity <= 1000,
            "Try buying less tickets! Running short!!"
        );
        require(
            _festivalERC.balanceOf(msg.sender, _currencyTokenId) >=
                _nftWeiPrice * quantity,
            "Insufficient balance to complete the purchase!"
        );
        /**
        @notice: First approve all the tokens to the contract. 
         */
        bool approved = _festivalERC.isApprovedForAll(
            msg.sender,
            address(this)
        );
        require(
            approved == true,
            "Approve the market contract first, then try buying!"
        );

        // transfer currecny token from msg.sender to market contract as required for fest ticket(s)
        _festivalERC.safeTransferFrom(
            msg.sender,
            address(this),
            _currencyTokenId,
            _nftWeiPrice * quantity,
            ""
        );
        // mint ticket(s) to msg.sender
        _festivalERC.mintCollectible("settlemint_fest", quantity, msg.sender);
        _ticketsSold = _ticketsSold + quantity;

        // _lastSalePrice defualts to 0 in map-> causes bugs when owner tries to sell in secondary market
        _lastSalePrice[msg.sender][_nftId] = _nftWeiPrice;
        emit FestTicketDirectSold(
            "settlemint_fest",
            payable(msg.sender),
            _nftWeiPrice, // wei-token
            quantity
        );
    }

    /**
    @dev Lists fest tickets for sale in secondary market.
    TODO: Currently we are not returning the ticketID. That ID should be fetched from event itself.
     */
    function listTicketForSale(uint256 tokenId, uint256 priceWeiToken)
        public
        payable
        nonReentrant
    {
        require(
            _festivalERC.balanceOf(msg.sender, tokenId) >= 1,
            "Doesn't have nft ticket to sell in account!"
        );
        uint256 priceCap = (11 * _lastSalePrice[msg.sender][tokenId]) / 10;
        require(
            priceWeiToken <= priceCap,
            "listing price can't be more than 10% of your last sale!"
        );
        require(
            msg.value ==
                (_currencyTokenWeiPrice * priceWeiToken) / (10 * (10**18)),
            "require listing fee {0.025 eth} for selling!"
        );
        /**
        @notice: First approve all the tokens to the contract.
        TODO: Approve by quantity.
        */
        bool approved = _festivalERC.isApprovedForAll(
            msg.sender,
            address(this)
        );
        require(
            approved == true,
            "Approve the market contract first, then try listing!"
        );
        _ticketIds.increment(); // 0 -> 1
        uint256 ticketId = _ticketIds.current(); // 1

        /**
        Creating fest ticket from struct.
         */
        _ticketIdTtoFestTicket[ticketId] = FestTicket(
            ticketId,
            tokenId,
            payable(address(0)),
            payable(msg.sender),
            priceWeiToken, // wei-token
            false
        );
        // transfer nft ticket to market contract
        _festivalERC.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            1,
            ""
        );
        emit FestTicketListed(
            ticketId,
            tokenId,
            payable(address(0)),
            payable(msg.sender),
            priceWeiToken, // wei-token
            false
        );
    }

    // buyTicketOnSale : buyer buys (nft)-(linked by ticketId) from seller (pay in eth or currencyToken ?)
    function buyTicketOnSale(uint256 ticketId) public payable nonReentrant {
        uint256 priceWeiToken = _ticketIdTtoFestTicket[ticketId].priceWeiToken;
        uint256 tokenId = _ticketIdTtoFestTicket[ticketId].tokenId;
        address seller = _ticketIdTtoFestTicket[ticketId].seller;
        require(
            _festivalERC.balanceOf(msg.sender, _currencyTokenId) >=
                priceWeiToken,
            "Insufficient currencyToken balance to complete the purchase!"
        );
        // first approve {account} and its assets for {operator} in script/test
        // NOTE: approval is not like erc20, can't specify amount for tokenId (TODO)
        bool approved = _festivalERC.isApprovedForAll(
            msg.sender,
            address(this)
        );
        require(
            approved == true,
            "Approve the market contract first, then try buying!"
        );
        // send tokens from buyer{msg.sender} to seller
        _festivalERC.safeTransferFrom(
            payable(msg.sender),
            payable(seller),
            _currencyTokenId,
            priceWeiToken,
            ""
        );
        // send nft ticket from market contract to buyer{msg.sender}
        _festivalERC.safeTransferFrom(
            payable(address(this)),
            payable(msg.sender),
            tokenId,
            1,
            ""
        );
        _ticketIdTtoFestTicket[ticketId].owner = payable(msg.sender);
        _ticketIdTtoFestTicket[ticketId].sold = true;
        emit FestTicketSold(
            ticketId,
            tokenId,
            payable(msg.sender),
            payable(seller),
            priceWeiToken,
            true
        );
        // update _lastSalePrice for seller in map -> not more than 10% hike rule
        _lastSalePrice[seller][tokenId] = priceWeiToken;

        // monetization in secondary sales for _organizer, 10% of the trade
        /**
        _currencyTokenWeiPrice -> Price of the currency token. (in eth)
        priceWeiToken -> Price of the ticket that seller listed. (in currency token)
         */
        payable(_organizer).transfer(
            (_currencyTokenWeiPrice * priceWeiToken) / (10 * (10**18))
        );
    }

    // fetchFestTicketsInSecondaryMarket -> sold and unsold all
    function fetchFestTicketsInSecondaryMarket()
        public
        view
        returns (FestTicket[] memory)
    {
        uint256 itemCount = _ticketIds.current();
        uint256 currentIndex = 0;
        FestTicket[] memory festTickets = new FestTicket[](itemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            uint256 ticketId = _ticketIdTtoFestTicket[i + 1].ticketId;
            FestTicket storage festTicket = _ticketIdTtoFestTicket[ticketId];
            festTickets[currentIndex] = festTicket;
            currentIndex += 1;
        }
        return festTickets;
    }

    // onERC1155Received -> must to receive ERC1155 NFTs
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
