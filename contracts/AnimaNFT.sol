//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IToucanContractRegistry.sol";

contract AnimaNFT is Ownable, ReentrancyGuard, ERC721 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // token symbol => token address
    mapping(string => address) public eligibleTokenAddresses;
    address public contractRegistryAddress =
        0x263fA1c180889b3a3f46330F32a4a23287E99FC9;
    address public sushiRouterAddress =
        0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    mapping(uint256 => uint256) public deposits;

    uint256 totalMinted;

    bool public isSaleActive = false;
    bool public is2ndSaleActive = false;
    bool public isFinalSaleActive = false;

    uint256 public RESERVED_AMOUNT = 50;
    uint256 public TOTAL_AMOUNT = 8888;

    uint256 public SALE_PRICE = 0.08 ether;
    address payable private ADMIN_WALLET =
        payable(0xD387098B3CA4C6D592Be0cE0B69E83BE86011c50);

    event Minted(
        address indexed minter,
        uint256 indexed startTokenId,
        uint256 indexed quantity,
        uint256 depositAmount,
        uint256 mintedAt
    );

    event Burnt(
        address indexed burner,
        uint256 indexed tokenId,
        uint256 indexed withdrawAmount,
        uint256 burntAt
    );

    constructor(
        string[] memory _eligibleTokenSymbols,
        address[] memory _eligibleTokenAddresses
    ) ERC721("Anima NFT", "ANIMA") {
        require(
            _eligibleTokenAddresses.length == _eligibleTokenSymbols.length,
            "Provide valid tokens"
        );
        uint256 i = 0;
        uint256 eligibleTokenSymbolsLen = _eligibleTokenSymbols.length;
        while (i < eligibleTokenSymbolsLen) {
            eligibleTokenAddresses[
                _eligibleTokenSymbols[i]
            ] = _eligibleTokenAddresses[i];
            i += 1;
        }
    }

    /**
     * @dev general sale function
     * @param _quantity amount to mint
     * @param _tokenAddress token user deposit
     * @param _amount token amount which user deposit
     */
    function mint(
        uint256 _quantity,
        address _tokenAddress,
        uint256 _amount
    ) external nonReentrant {
        /// check if sale start or not
        require(isSaleActive, "Sale not started yet");

        /// check if user can mint _quantity amount of NFT
        require(
            totalMinted + _quantity < RESERVED_AMOUNT + TOTAL_AMOUNT,
            "Exceed total Sale amount"
        );

        uint256 realNCTAmount = 0; /// actual NCT amount which user will send to mint
        IERC20 NCT_TOKEN = IERC20(eligibleTokenAddresses["NCT"]);

        if (eligibleTokenAddresses["NCT"] == _tokenAddress) {
            /// check if user have enough NCT token to send
            require(_amount >= SALE_PRICE * _quantity, "Not enough payment");

            /// transfer NCT token from caller to this contract
            NCT_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
            realNCTAmount = _amount;
        } else {
            IERC20 userToken = IERC20(_tokenAddress);

            /// check if user have enough balance of token to send
            uint256 walletAmount = userToken.balanceOf(msg.sender);
            require(walletAmount >= _amount, "token amount is not enough");

            /// check if user deposit enough value of token
            uint256 expectedNCTAmount = convertNCTAmount(
                _tokenAddress,
                eligibleTokenAddresses["NCT"],
                _amount
            );
            require(
                expectedNCTAmount >= SALE_PRICE * _quantity,
                "Not enough payment"
            );

            /// transfer user's token to this contract after checking all validation
            userToken.safeTransferFrom(msg.sender, address(this), _amount);

            /// approve sushiswap to send tokens from user to swap NCT token
            userToken.approve(sushiRouterAddress, _amount);

            /// swap token into NCT thru sushiswap
            uint256[] memory amounts = swap(
                _tokenAddress,
                eligibleTokenAddresses["NCT"],
                _amount
            );
            realNCTAmount = amounts[2];
        }

        /// calculate user deposit and platform fee
        uint256 platformFee = realNCTAmount / 5;
        uint256 actualUserDeposit = realNCTAmount - platformFee;

        /// transfer platformFee to admin wallet
        NCT_TOKEN.safeTransferFrom(address(this), ADMIN_WALLET, platformFee);

        /// actual mint after receiving tokens
        for (uint256 i = 0; i < _quantity; i++) {
            _safeMint(msg.sender, totalMinted + i);
            deposits[totalMinted + i] += actualUserDeposit / _quantity;
        }
        totalMinted = totalMinted + _quantity;

        emit Minted(
            msg.sender,
            totalMinted - _quantity,
            _quantity,
            realNCTAmount,
            block.timestamp
        );
    }

    function withdrawBurn(uint256 _tokenId) external nonReentrant {
        require(
            ownerOf(_tokenId) == msg.sender,
            "sender is not owner of this token id"
        );

        /// burn certain tokenId
        _burn(_tokenId);

        /// send back deposited NCT to user
        uint256 depositedAmount = deposits[_tokenId];
        IERC20(eligibleTokenAddresses["NCT"]).safeTransferFrom(
            address(this),
            msg.sender,
            depositedAmount
        );

        /// reset user deposit amount to zero
        deposits[_tokenId] = 0;

        emit Burnt(msg.sender, _tokenId, depositedAmount, block.timestamp);
    }

    /**
     * @dev uses SushiSwap to exchange eligible tokens for BCT / NCT
     * @param _fromToken token to deposit and swap
     * @param _toToken token to swap for (will be held within contract)
     * @param _amount amount of NCT / BCT wanted
     * @notice needs to be approved on the client side
     */
    function swap(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) public returns (uint256[] memory) {
        // check tokens
        require(
            isSwapable(_fromToken) && isRedeemable(_toToken),
            "Can't swap this token"
        );

        // transfer token from user to this contract
        IERC20(_fromToken).safeTransferFrom(msg.sender, address(this), _amount);

        // approve sushi router
        IERC20(_fromToken).approve(sushiRouterAddress, _amount);

        // instantiate sushi router
        IUniswapV2Router02 routerSushi = IUniswapV2Router02(sushiRouterAddress);

        // establish path (in most cases token -> USDC -> NCT/BCT should work)
        address[] memory path = new address[](3);
        path[0] = _fromToken;
        path[1] = eligibleTokenAddresses["USDC"];
        path[2] = _toToken;

        // swap input token for pool token
        uint256[] memory amountsIn = routerSushi.getAmountsIn(_amount, path);
        routerSushi.swapTokensForExactTokens(
            _amount,
            amountsIn[2],
            path,
            address(this),
            block.timestamp
        );

        return amountsIn;
    }

    /**
     * @dev uses SushiSwap to get eligible token amount for BCT / NCT
     * @param _fromToken token to deposit and swap
     * @param _toToken token to swap for (will be held within contract)
     * @param _amount amount of NCT / BCT wanted
     * @notice needs to be approved on the client side
     */
    function convertNCTAmount(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) public returns (uint256) {
        // check tokens
        require(
            isSwapable(_fromToken) && isRedeemable(_toToken),
            "Can't swap this token"
        );

        // transfer token from user to this contract
        IERC20(_fromToken).safeTransferFrom(msg.sender, address(this), _amount);

        // approve sushi router
        IERC20(_fromToken).approve(sushiRouterAddress, _amount);

        // instantiate sushi router
        IUniswapV2Router02 routerSushi = IUniswapV2Router02(sushiRouterAddress);

        // establish path (in most cases token -> USDC -> NCT/BCT should work)
        address[] memory path = new address[](3);
        path[0] = _fromToken;
        path[1] = eligibleTokenAddresses["USDC"];
        path[2] = _toToken;

        // swap input token for pool token
        uint256[] memory amountsIn = routerSushi.getAmountsIn(_amount, path);

        return amountsIn[2];
    }

    /**
     * @dev checks address and returns if can be used at all by the contract
     * @param _erc20Address address of token to be checked
     */
    function isEligible(address _erc20Address) private view returns (bool) {
        bool isToucanContract = IToucanContractRegistry(contractRegistryAddress)
            .checkERC20(_erc20Address);
        if (isToucanContract) return true;
        if (_erc20Address == eligibleTokenAddresses["BCT"]) return true;
        if (_erc20Address == eligibleTokenAddresses["NCT"]) return true;
        if (_erc20Address == eligibleTokenAddresses["USDC"]) return true;
        if (_erc20Address == eligibleTokenAddresses["WETH"]) return true;
        if (_erc20Address == eligibleTokenAddresses["WMATIC"]) return true;
        return false;
    }

    /**
     * @dev checks address and returns if it can be used in a swap
     * @param _erc20Address address of token to be checked
     */
    function isSwapable(address _erc20Address) private view returns (bool) {
        if (_erc20Address == eligibleTokenAddresses["USDC"]) return true;
        if (_erc20Address == eligibleTokenAddresses["WETH"]) return true;
        if (_erc20Address == eligibleTokenAddresses["WMATIC"]) return true;
        return false;
    }

    /**
     * @dev checks address and returns if can it's a pool token and can be redeemed
     * @param _erc20Address address of token to be checked
     */
    function isRedeemable(address _erc20Address) private view returns (bool) {
        if (_erc20Address == eligibleTokenAddresses["BCT"]) return true;
        if (_erc20Address == eligibleTokenAddresses["NCT"]) return true;
        return false;
    }

    /**
     * @dev tells user how much ETH/MATIC is required to swap for an amount of specified tokens
     * @param _toToken token to swap for (should be NCT or BCT)
     * @param _amount amount of NCT / BCT wanted
     * @return uint256 representing the required ETH / MATIC to get the amount of NCT / BCT
     */
    function estimateTokenToSwap(address _toToken, uint256 _amount)
        public
        view
        returns (uint256)
    {
        // require token to be redeemable
        require(isRedeemable(_toToken), "Can't swap for this token");

        // instantiate sushi router
        IUniswapV2Router02 routerSushi = IUniswapV2Router02(sushiRouterAddress);

        // establish path;
        // sushi router expects path[0] == WMATIC, but otherwise the path will resemble the one above
        address[] memory path = new address[](3);
        path[0] = eligibleTokenAddresses["WMATIC"];
        path[1] = eligibleTokenAddresses["USDC"];
        path[2] = _toToken;

        // get and return the amount needed to send to get the mentioned tokens
        uint256[] memory amounts = routerSushi.getAmountsIn(_amount, path);
        return amounts[0];
    }

    /// -------- Admin functions ---------- ///

    /**
     * @dev mint NFTs to team
     * @param to_ address to mint
     * @param quantity_ amount of nft to be minted
     */
    function mintToTeam(address to_, uint256 quantity_) external onlyOwner {
        require(
            totalMinted + quantity_ < RESERVED_AMOUNT,
            "Exceeds reserved amount for team"
        );
        _safeMint(to_, quantity_);
    }

    /**
     * @dev toggle sale active/deactive
     */
    function toggleSaleActive() external onlyOwner {
        isSaleActive = !isSaleActive;
    }

    /**
     * @dev update contract registry address, sushiRouterAddress
     * @param contractRegistryAddress_ address for registry
     * @param sushiRouterAddress_ address of sushi swap
     * @param adminWallet_ address of admin layer
     */
    function updateContractAddresses(
        address contractRegistryAddress_,
        address sushiRouterAddress_,
        address adminWallet_
    ) external {
        contractRegistryAddress = contractRegistryAddress_;
        sushiRouterAddress = sushiRouterAddress_;
        ADMIN_WALLET = payable(adminWallet_);
    }
}
