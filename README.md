# 🏪 Franchain - On-Chain Franchise System

A decentralized franchise management system built on Stacks that enables transparent licensing, revenue tracking, and royalty distribution across franchise locations.

## 🌟 Features

- **🏢 Franchise Creation**: Deploy new franchise concepts with customizable fees and royalty rates
- **📍 Location Licensing**: Purchase and manage franchise licenses for specific locations
- **💰 Revenue Tracking**: Automated royalty collection and revenue monitoring
- **⏰ License Management**: Time-based licensing with renewal capabilities
- **🔐 Access Control**: Role-based permissions for franchise owners and operators
- **📊 Analytics**: Track performance metrics across franchises and locations

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd franchain
clarinet check
```

## 🔧 Usage

### Creating a Franchise

Only the contract owner can create new franchises:

```clarity
;; Create a new franchise with 1000 STX fee and 5% royalty rate
(contract-call? .franchain create-franchise "Pizza Palace" u1000000 u500)
```

### Purchasing a License

Any user can purchase a franchise license:

```clarity
;; Purchase a 1-year license (52560 blocks ≈ 1 year)
(contract-call? .franchain purchase-license u1 'ST1OPERATOR123... "123 Main St, City" u52560)
```

### Recording Revenue

Licensed operators can record revenue (automatic royalty payment):

```clarity
;; Record 10 STX in revenue (royalties automatically sent to franchise owner)
(contract-call? .franchain record-revenue u1 u10000000)
```

### Renewing License

Extend your franchise license before it expires:

```clarity
;; Renew license for another year
(contract-call? .franchain renew-license u1 u52560)
```

## 📋 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-franchise` | 🆕 Create new franchise | name, fee, royalty-rate |
| `purchase-license` | 🛒 Buy franchise license | franchise-id, operator, address, duration |
| `record-revenue` | 📈 Log revenue & pay royalties | location-id, amount |
| `renew-license` | 🔄 Extend license duration | location-id, duration |
| `deactivate-location` | ❌ Disable location | location-id |
| `update-franchise-status` | 🔧 Toggle franchise active status | franchise-id, active |
| `update-franchise-fee` | 💲 Change franchise fee | franchise-id, new-fee |
| `transfer-franchise-ownership` | 👥 Transfer franchise to new owner | franchise-id, new-owner |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-franchise` | 📋 Get franchise details | Franchise data |
| `get-location` | 🏪 Get location details | Location data |
| `is-license-valid` | ✅ Check license validity | Boolean |
| `get-franchise-count` | 🔢 Total franchises | Number |
| `get-location-count` | 📍 Total locations | Number |
| `get-total-revenue` | 💰 System-wide revenue | Amount |
| `calculate-royalty` | 🧮 Calculate royalty amount | Amount |

## 💡 Key Concepts

### 🏢 Franchises
- Owned by franchise creators
- Define licensing fees and royalty rates
- Can be activated/deactivated by owners
- Support ownership transfers

### 📍 Locations
- Licensed by operators
- Have expiration dates requiring renewal
- Track individual revenue and performance
- Can be deactivated by operators

### 💸 Revenue Model
- License fees paid upfront to franchise owners
- Ongoing royalties automatically collected on revenue recording
- Transparent tracking of all financial flows

## 🔒 Security Features

- **Access Control**: Role-based permissions for all operations
- **License Validation**: Automatic expiry checking
- **Payment Verification**: Ensures sufficient balance before transactions
- **Data Integrity**: Immutable on-chain record keeping

## 🧪 Testing

```bash
clarinet test
```

## 📝 Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Resource not found |
| u102 | Resource already exists |
| u103 | Insufficient payment |
| u104 | Invalid location |
| u105 | License expired |
| u106 | Inactive franchise |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)
