// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Treasury is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant INVESTOR_ROLE = keccak256("INVESTOR_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    enum FundCategory { OPERATIONAL, INVESTMENT, EMERGENCY, DEVELOPMENT }

    struct Allocation {
        uint256 amount;
        uint256 timestamp;
        address recipient;
        FundCategory category;
        bool executed;
        string description;
    }

    mapping(uint256 => Allocation) public allocations;
    uint256 public allocationCount;

    mapping(FundCategory => uint256) public categoryBalances;
    mapping(FundCategory => uint256) public categoryLimits;

    event AllocationProposed(uint256 indexed allocationId, FundCategory category, uint256 amount, address recipient, string description);
    event AllocationExecuted(uint256 indexed allocationId, address executor);
    event FundsDeposited(address indexed depositor, uint256 amount, FundCategory category);
    event CategoryLimitUpdated(FundCategory category, uint256 newLimit);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURER_ROLE, admin);
        _grantRole(INVESTOR_ROLE, admin);
        _grantRole(AUDITOR_ROLE, admin);

        // Set initial category limits (example values)
        categoryLimits[FundCategory.OPERATIONAL] = 100 ether;
        categoryLimits[FundCategory.INVESTMENT] = 500 ether;
        categoryLimits[FundCategory.EMERGENCY] = 50 ether;
        categoryLimits[FundCategory.DEVELOPMENT] = 200 ether;
    }

    function proposeAllocation(
        uint256 amount,
        FundCategory category,
        address recipient,
        string memory description
    ) external onlyRole(TREASURER_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        require(recipient != address(0), "Invalid recipient");
        require(categoryBalances[category] + amount <= categoryLimits[category], "Exceeds category limit");

        allocationCount++;
        allocations[allocationCount] = Allocation({
            amount: amount,
            category: category,
            recipient: recipient,
            description: description,
            timestamp: block.timestamp,
            executed: false
        });

        emit AllocationProposed(allocationCount, category, amount, recipient, description);
    }

    function executeAllocation(uint256 allocationId) external onlyRole(INVESTOR_ROLE) nonReentrant {
        Allocation storage allocation = allocations[allocationId];
        require(!allocation.executed, "Allocation already executed");
        require(categoryBalances[allocation.category] >= allocation.amount, "Insufficient funds in category");

        allocation.executed = true;
        categoryBalances[allocation.category] -= allocation.amount;

        // Transfer funds (assuming native token for simplicity, can be extended for ERC20)
        payable(allocation.recipient).transfer(allocation.amount);

        emit AllocationExecuted(allocationId, msg.sender);
    }

    function depositFunds(FundCategory category) external payable onlyRole(TREASURER_ROLE) {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        categoryBalances[category] += msg.value;
        emit FundsDeposited(msg.sender, msg.value, category);
    }

    function depositERC20(address token, uint256 amount, FundCategory category) external onlyRole(TREASURER_ROLE) {
        require(amount > 0, "Deposit amount must be greater than 0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // Note: For ERC20, we might need separate tracking, but for simplicity, assuming native token
    }

    function updateCategoryLimit(FundCategory category, uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        categoryLimits[category] = newLimit;
        emit CategoryLimitUpdated(category, newLimit);
    }

    function getAllocation(uint256 allocationId) external view returns (Allocation memory) {
        return allocations[allocationId];
    }

    function getCategoryBalance(FundCategory category) external view returns (uint256) {
        return categoryBalances[category];
    }

    function getCategoryLimit(FundCategory category) external view returns (uint256) {
        return categoryLimits[category];
    }

    // Emergency function to pause allocations
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Implementation for pausing
    }

    receive() external payable {}
}
