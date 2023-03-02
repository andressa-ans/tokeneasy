import SecurityToken from "SecurityToken.cdc"

pub contract ExampleToken: SecurityToken {

    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // Total supply of Flow tokens in existence
    pub var totalSupply: UInt64

    /// The status of contract lock
    pub var isLocked: Bool

    // Adresses allowed to hold tokens
    pub var whitelist: [Address]

    // Document struct that specify the rules of the token
    pub struct Document {
        pub var name: String
        pub var uri: String
        pub var hash: String

        init(name: String, uri: String, hash: String) {
            self.name = name
            self.uri = uri
            self.hash = hash
        }
    }

    // Document list that specify the rules of the token
    pub var documents: [Document]

    // Event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UInt64)

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UInt64, from: Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UInt64, to: Address?)

    // Event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UInt64)

    // Event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UInt64)

    // Event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UInt64)

    // Event that is emitted when a new burner resource is created
    pub event BurnerCreated()

       /// The event that is emitted when wallet is added to whitelist
    pub event AddedToWhitelist(address: Address?)

    /// The event that is emitted when wallet is removed to whitelist
    pub event RemovedFromWhitelist(address: Address?, reason: String)

    /// The event that is emitted when new document is added
    pub event DocumentAdded(index: Int, name: String, uri: String, hash: String)

    /// The event that is emitted when wallet is removed to whitelist
    pub event DocumentRemoved(index: Int)

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault and governed by the pre and post conditions
    // in SecurityToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault: SecurityToken.Provider, SecurityToken.Receiver, SecurityToken.Balance {

        // holds the balance of a users tokens
        pub var balance: UInt64

        // initialize the balance at resource creation time
        init(balance: UInt64) {
            self.balance = balance
        }

        // withdraw
        //
        // Function that takes an integer amount as an argument
        // and withdraws that amount from the Vault.
        // It creates a new temporary Vault that is used to hold
        // the money that is being transferred. It returns the newly
        // created Vault to the context that called so it can be deposited
        // elsewhere.
        //
        pub fun withdraw(amount: UInt64): @SecurityToken.Vault {
            if ExampleToken.isLocked {
                panic("Contract is locked")
            }

            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and adds
        // its balance to the balance of the owners Vault.
        // It is allowed to destroy the sent Vault because the Vault
        // was a temporary holder of the tokens. The Vault's balance has
        // been consumed and therefore can be destroyed.
        pub fun deposit(from: @SecurityToken.Vault) {
            if ExampleToken.whitelist.contains(self.owner?.address!) == false {
                panic("Address not whitelisted")
            }

            let vault <- from as! @ExampleToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0
            destroy vault
        }

        destroy() {
            if self.balance > 0 {
                ExampleToken.totalSupply = ExampleToken.totalSupply - self.balance
            }
        }
    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(): @SecurityToken.Vault {
        return <-create Vault(balance: 0)
    }

    pub resource Administrator {
        // createNewMinter
        //
        // Function that creates and returns a new minter resource
        //
        pub fun createNewMinter(allowedAmount: UInt64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }

        // createNewBurner
        //
        // Function that creates and returns a new burner resource
        //
        pub fun createNewBurner(): @Burner {
            emit BurnerCreated()
            return <-create Burner()
        }

        pub fun addToWhitelist(address: Address) {
            ExampleToken.whitelist.insert(at: ExampleToken.whitelist.length, address)
            emit AddedToWhitelist(address: address)
        }

        pub fun removeFromWhitelist(address: Address) {
            let index = ExampleToken.whitelist.firstIndex(of: address)

            if index != nil {
                ExampleToken.whitelist.remove(at: index!)
                emit RemovedFromWhitelist(address: address, reason: "Removed from whitelist")
            } else {
                panic("Address not found in whitelist")
            }
        }

        pub fun addDocument(name: String, uri: String, hash: String) {
            ExampleToken.documents.insert(at: ExampleToken.documents.length, Document(name: name, uri: uri, hash: hash))
            emit DocumentAdded(index: ExampleToken.documents.length - 1, name: name, uri: uri, hash: hash)
        }

        pub fun removeDocument(index: Int) {
            ExampleToken.documents.remove(at: index)
            emit DocumentRemoved(index: index)
        }

        pub fun lock() {
            ExampleToken.isLocked = true
        }

        pub fun unlock() {
            ExampleToken.isLocked = false
        }
    }

    // Minter
    //
    // Resource object that token admin accounts can hold to mint new tokens.
    //
    pub resource Minter {

        // the amount of tokens that the minter is allowed to mint
        pub var allowedAmount: UInt64

        // mintTokens
        //
        // Function that mints new tokens, adds them to the total supply,
        // and returns them to the calling context.
        //
        pub fun mintTokens(amount: UInt64): @ExampleToken.Vault {
            pre {
                amount > UInt64(0): "Amount minted must be greater than zero"
                amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
            }
            ExampleToken.totalSupply = ExampleToken.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }

        init(allowedAmount: UInt64) {
            self.allowedAmount = allowedAmount
        }
    }

    // Burner
    //
    // Resource object that token admin accounts can hold to burn tokens.
    //
    pub resource Burner {

        // burnTokens
        //
        // Function that destroys a Vault instance, effectively burning the tokens.
        //
        // Note: the burned tokens are automatically subtracted from the
        // total supply in the Vault destructor.
        //
        pub fun burnTokens(from: @SecurityToken.Vault) {
            let vault <- from as! @ExampleToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }
    }

    init() {
        self.VaultStoragePath = /storage/exampleTokenVault
        self.VaultPublicPath = /public/exampleTokenVault
        self.ReceiverPublicPath = /public/exampleTokenReceiver
        self.AdminStoragePath = /storage/exampleTokenAdmin

        self.totalSupply = 0
        self.whitelist = [self.account.address]
        self.documents = []
        self.isLocked = true

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)

        
        self.account.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        self.account.link<&ExampleToken.Vault{SecurityToken.Receiver}>(
            self.ReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        self.account.link<&ExampleToken.Vault{SecurityToken.Balance}>(
            self.VaultPublicPath,
            target: self.VaultStoragePath
        )

        let admin <- create Administrator()
        
        self.account.save(<-admin, to: self.AdminStoragePath)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
 