/// The interface that Security Token contracts implement.
///
pub contract interface SecurityToken {
    /// The total number of tokens in existence.
    /// It is up to the implementer to ensure that the total supply
    /// stays accurate and up to date
    pub var totalSupply: UInt64

    /// Adresses allowed to hold tokens
    pub var whitelist: [Address]

    /// The status of contract lock
    pub var isLocked: Bool

    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UInt64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UInt64, from: Address?)

    /// The event that is emitted when tokens are deposited into a Vault
    pub event TokensDeposited(amount: UInt64, to: Address?)

    /// The event that is emitted when wallet is added to whitelist
    pub event AddedToWhitelist(address: Address?)

    /// The event that is emitted when wallet is removed to whitelist
    pub event RemovedFromWhitelist(address: Address?, reason: String)

    /// The event that is emitted when new document is added
    pub event DocumentAdded(index: Int, name: String, uri: String, hash: String)

    /// The event that is emitted when wallet is removed to whitelist
    pub event DocumentRemoved(index: Int)


    /// The interface that enforces the requirements for withdrawing
    /// tokens from the implementing type.
    ///
    /// It does not enforce requirements on `balance` here,
    /// because it leaves open the possibility of creating custom providers
    /// that do not necessarily need their own balance.
    ///
    pub resource interface Provider {

        /// Subtracts tokens from the owner's Vault
        /// and returns a Vault with the removed tokens.
        ///
        /// The function's access level is public, but this is not a problem
        /// because only the owner storing the resource in their account
        /// can initially call this function.
        ///
        /// The owner may grant other accounts access by creating a private
        /// capability that allows specific other users to access
        /// the provider resource through a reference.
        ///
        /// The owner may also grant all accounts access by creating a public
        /// capability that allows all users to access the provider
        /// resource through a reference.
        ///
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        /// 
        pub fun withdraw(amount: UInt64): @Vault {
            post {
                // `result` refers to the return value
                result.balance == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Vault"
            }
        }
    }

    /// The interface that enforces the requirements for depositing
    /// tokens into the implementing type.
    ///
    /// We do not include a condition that checks the balance because
    /// we want to give users the ability to make custom receivers that
    /// can do custom things with the tokens, like split them up and
    /// send them to different places.
    ///
    pub resource interface Receiver {

        /// Takes a Vault and deposits it into the implementing resource type
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        pub fun deposit(from: @Vault)
    }

    /// The interface that contains the `balance` field of the Vault
    /// and enforces that when new Vaults are created, the balance
    /// is initialized correctly.
    ///
    pub resource interface Balance {

        /// The total balance of a vault
        ///
        pub var balance: UInt64

        init(balance: UInt64) {
            post {
                self.balance == balance:
                    "Balance must be initialized to the initial balance"
            }
        }
    }

    /// The resource that contains the functions to send and receive tokens.
    /// The declaration of a concrete type in a contract interface means that
    /// every Fungible Token contract that implements the SecurityToken interface
    /// must define a concrete `Vault` resource that conforms to the `Provider`, `Receiver`,
    /// and `Balance` interfaces, and declares their required fields and functions
    ///
    pub resource Vault: Provider, Receiver, Balance {

        /// The total balance of the vault
        pub var balance: UInt64

        // The conforming type must declare an initializer
        // that allows providing the initial balance of the Vault
        //
        init(balance: UInt64)

        /// Subtracts `amount` from the Vault's balance
        /// and returns a new Vault with the subtracted balance
        ///
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        ///
        pub fun withdraw(amount: UInt64): @Vault {
            pre {
                self.balance >= amount:
                    "Amount withdrawn must be less than or equal than the balance of the Vault"
            }
            post {
                // use the special function `before` to get the value of the `balance` field
                // at the beginning of the function execution
                //
                self.balance == before(self.balance) - amount:
                    "New Vault balance must be the difference of the previous balance and the withdrawn Vault"
            }
        }

        /// Takes a Vault and deposits it into the implementing resource type
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        pub fun deposit(from: @Vault) {
            // Assert that the concrete type of the deposited vault is the same
            // as the vault that is accepting the deposit
            pre {
                from.isInstance(self.getType()): 
                    "Cannot deposit an incompatible token type"
            }
            post {
                self.balance == before(self.balance) + before(from.balance):
                    "New Vault balance must be the sum of the previous balance and the deposited Vault"
            }
        }
    }

    /// Allows any user to create a new Vault that has a zero balance
    ///
    /// @return The new Vault resource
    ///
    pub fun createEmptyVault(): @Vault {
        post {
            result.balance == 0: "The newly created Vault must have zero balance"
        }
    }
}