// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Vault {
    /// Errors
    error Vault__Not_the_contact_owner();
    error Vault__Max_contacts_reached();
    error Vault__Missing_required_infos();
    error Vault__Contact_not_exists();
    error Vault__Contact_already_exists(string firstname, string lastname);

    /// Events
    event ContactAdded(
        uint256 indexed id,
        string indexed firstname,
        string indexed lastname,
        string email,
        string phone,
        Category category,
        string physicalAddress
    );

    event ContactUpdated(
        uint256 indexed id,
        string indexed firstname,
        string indexed lastname,
        string email,
        string phone,
        string physicalAddress,
        Category category
    );

    event ContactDeleted(uint256 id);

    enum Category {
        Friend,
        Family,
        Professional,
        Other
    }

    struct Contact {
        uint256 id;
        string firstname;
        string lastname;
        string email;
        string phone;
        string physicalAddress;
        Category category;
    }

    address private immutable OWNER;
    uint256 constant MAX_CONTACTS_PER_USER = 500;
    uint256 constant MAX_CATEGORIES_PER_USER = 10;

    // uint256 lastIndex = 0;
    mapping(address user => uint256 lastIndex) userLastContactIndex;
    /**
     * @notice Maps a user's address to their contacts
     */
    mapping(address user => Contact[] contacts) internal userContacts;
    /**
     * @notice Retrieve user's address specific contact index
     */
    mapping(address user => mapping(uint256 id => uint256 index))
        internal userContactToIndex;

    // /**
    //  * @notice Tells if a contact exists with given contactId
    //  */
    // mapping(uint256 contactId => bool existing) internal contactExisting;

    /**
     * @notice Map user's address contact fullname with corresponding contact id
     */
    mapping(address user => mapping(string fullname => uint256 contactId))
        internal userContactFullnameExisting;

    /**
     * Tells if user has contact with given id
     */
    mapping(address user => mapping(uint256 contactId => bool existing)) userContactExists;

    mapping(address user => mapping(Category category => uint256[] contactsIds))
        internal userContactsByCategory;

    /**
     * @notice Tells if category has at least one contact attached
     */
    mapping(string category => bool hasContact) internal categoryHasContact;

    //// Modifiers

    modifier checkContactDuplicating(
        string memory _firstname,
        string memory _lastname
    ) {
        if (
            userContactFullnameExisting[msg.sender][
                computeFullname(_firstname, _lastname)
            ] != 0
        ) {
            revert Vault__Contact_already_exists(_firstname, _lastname);
        }
        _;
    }

    modifier userHasContact(uint256 _contactId) {
        if (!userContactExists[msg.sender][_contactId]) {
            revert Vault__Not_the_contact_owner();
        }
        _;
    }

    modifier requireLastNameAndFirstname(
        string memory _firstname,
        string memory _lastname
    ) {
        if (isStrEmpty(_firstname) || isStrEmpty(_lastname)) {
            revert Vault__Missing_required_infos();
        }
        _;
    }

    /**
     * @notice Constructor
     */
    constructor() {
        OWNER = msg.sender;
    }

    /// Public functions

    /**
     * @notice Create new contact for the msg.sender with given params
     *
     * @param _firstname contact firsname
     * @param _lastname contact lastname
     * @param _email contact email
     * @param _phone contact phone number
     * @param _category category of contact
     * @param _physicalAddress physical address of contact
     *
     * @return contact the just created contact
     */
    function addContact(
        string memory _firstname,
        string memory _lastname,
        string memory _email,
        string memory _phone,
        Category _category,
        string memory _physicalAddress
    )
        public
        requireLastNameAndFirstname(_firstname, _lastname)
        checkContactDuplicating(_firstname, _lastname)
        returns (Contact memory)
    {
        Contact[] storage contacts = userContacts[msg.sender];
        uint256 contactsLength = contacts.length;
        if (contactsLength == MAX_CONTACTS_PER_USER) {
            revert Vault__Max_contacts_reached();
        }

        uint256 newContactId = userLastContactIndex[msg.sender] + 1;

        Contact memory contact = Contact({
            id: newContactId,
            firstname: _firstname,
            lastname: _lastname,
            email: _email,
            phone: _phone,
            physicalAddress: _physicalAddress,
            category: _category
        });

        contacts.push(contact);
        userContactToIndex[msg.sender][newContactId] = contactsLength;
        userContactFullnameExisting[msg.sender][
            computeFullname(_firstname, _lastname)
        ] = newContactId;
        userContactsByCategory[msg.sender][_category].push(newContactId);

        userLastContactIndex[msg.sender]++;

        emit ContactAdded(
            newContactId,
            _firstname,
            _lastname,
            _email,
            _phone,
            _category,
            _physicalAddress
        );

        return contact;
    }

    function updateContact(
        uint256 _contactId,
        string memory _firstname,
        string memory _lastname,
        string memory _email,
        string memory _phone,
        string memory _physicalAddress,
        Category _category
    )
        public
        // contactExists(_contactId)
        userHasContact(_contactId)
        returns (Contact memory)
    {
        address msgSender = msg.sender;
        uint256 contactIndex = userContactToIndex[msgSender][_contactId];
        Contact storage contact = userContacts[msgSender][contactIndex];

        string memory oldFirstname = contact.firstname;
        string memory oldLastname = contact.lastname;
        Category oldCategory = contact.category;

        string memory updatedFirstname = isStrEmpty(_firstname)
            ? oldFirstname
            : _firstname;
        string memory updatedLastname = isStrEmpty(_lastname)
            ? oldLastname
            : _lastname;

        bool categoryChanged = _category != oldCategory;
        Category updatedCategory = categoryChanged ? _category : oldCategory;

        bool firstnameChanged = !isStrEmpty(_firstname) &&
            !compareStrings(_firstname, oldFirstname);
        bool lastnameChanged = !isStrEmpty(_lastname) &&
            !compareStrings(_lastname, oldLastname);

        if (firstnameChanged || lastnameChanged) {
            string memory newFullname = computeFullname(
                updatedFirstname,
                updatedLastname
            );
            string memory oldFullname = computeFullname(
                oldFirstname,
                oldLastname
            );

            if (userContactFullnameExisting[msgSender][newFullname] != 0) {
                revert Vault__Contact_already_exists(
                    updatedFirstname,
                    updatedLastname
                );
            }

            userContactFullnameExisting[msgSender][oldFullname] = 0;
            userContactFullnameExisting[msgSender][newFullname] = contact.id;
        }

        if (categoryChanged) {
            uint256[] storage oldCategoryContactsIds = userContactsByCategory[
                msgSender
            ][oldCategory];
            uint256 oldCategotyIdsLength = oldCategoryContactsIds.length;

            if (oldCategotyIdsLength == 1) {
                oldCategoryContactsIds.pop();
            } else {
                for (uint256 i = 0; i < oldCategotyIdsLength; ) {
                    if (oldCategoryContactsIds[i] == _contactId) {
                        oldCategoryContactsIds[i] = oldCategoryContactsIds[
                            oldCategotyIdsLength - 1
                        ];
                        oldCategoryContactsIds.pop();
                        break;
                    }

                    unchecked {
                        ++i;
                    }
                }
            }
        }

        contact.firstname = updatedFirstname;
        contact.lastname = updatedLastname;
        contact.email = isStrEmpty(_email) ? contact.email : _email;
        contact.phone = isStrEmpty(_phone) ? contact.phone : _phone;
        contact.category = updatedCategory;
        contact.physicalAddress = isStrEmpty(_physicalAddress)
            ? contact.physicalAddress
            : _physicalAddress;

        emit ContactUpdated(
            contact.id,
            contact.firstname,
            contact.lastname,
            contact.email,
            contact.phone,
            contact.physicalAddress,
            contact.category
        );

        return contact;
    }

    function deleteContact(
        uint256 _contactId
    ) public userHasContact(_contactId) {
        uint256 contactIndex = userContactToIndex[msg.sender][_contactId]; // Get contact index

        Contact[] storage contacts = userContacts[msg.sender]; // get user contacts
        uint256 contactsLength = contacts.length;

        Contact memory contact = contacts[contactIndex];

        uint256[] storage userCategoryContactsIds = userContactsByCategory[
            msg.sender
        ][contact.category];
        uint256 contactIdsLength = userCategoryContactsIds.length;

        uint256 latestContactId = contacts[contactsLength - 1].id; // Get the latest contact id to update his index in array later

        userContactToIndex[msg.sender][latestContactId] = contactIndex; // update index of the element moved

        userContactFullnameExisting[msg.sender][
            computeFullname(contact.firstname, contact.lastname)
        ] = 0;

        if (contacts.length > 1) {
            contacts[contactIndex] = contacts[contacts.length - 1]; // replace value at the contactIndex by the latest value in the array
        }
        contacts.pop(); // delete latest element

        if (contactIdsLength == 1) {
            userCategoryContactsIds.pop();
        } else {
            for (uint256 i; i < contactIdsLength; ) {
                if (userCategoryContactsIds[i] == _contactId) {
                    userCategoryContactsIds[i] = userCategoryContactsIds[
                        contactIdsLength - 1
                    ];
                    userCategoryContactsIds.pop();
                    break;
                }

                unchecked {
                    ++i;
                }
            }
        }

        emit ContactDeleted(_contactId);
    }

    function filterContactsByCategory(
        Category _category
    ) public view returns (Contact[] memory) {
        uint256[] memory contactsIds = userContactsByCategory[msg.sender][
            _category
        ]; // Get contacts ids for the given category
        uint256 contactsIdLength = contactsIds.length;

        Contact[] memory _userContacts = userContacts[msg.sender];

        Contact[] memory resultContacts = new Contact[](contactsIdLength);

        for (uint256 i = 0; i < contactsIdLength; ) {
            uint256 contactIndex = userContactToIndex[msg.sender][
                contactsIds[i]
            ]; // get the contact index

            Contact memory contact = _userContacts[contactIndex]; // Get the contact

            resultContacts[i] = contact; // push contact into contacts array

            unchecked {
                ++i;
            }
        }

        return resultContacts;
    }

    function searchContactsByName(
        string memory _firstname,
        string memory _lastname
    ) public view returns (Contact memory) {
        string memory fullname = computeFullname(_firstname, _lastname);

        uint256 contactId = userContactFullnameExisting[msg.sender][fullname];

        if (contactId == 0) {
            revert Vault__Contact_not_exists();
        }

        uint256 contactIndex = userContactToIndex[msg.sender][contactId];
        Contact[] memory contacts = userContacts[msg.sender];
        Contact memory contact = contacts[contactIndex];

        return contact;
    }

    /**
     * @notice Compare two strings
     * @param a First string
     * @param b Second string
     */
    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return
            bytes(a).length == bytes(b).length &&
            keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /// Internal functions

    /**
     * @notice Compute fullname from firstname and lastname
     * @param _firstname firstname
     * @param _lastname lastname
     * @return fullname computed fullname
     */
    function computeFullname(
        string memory _firstname,
        string memory _lastname
    ) internal pure returns (string memory) {
        return string.concat(_firstname, "_", _lastname);
    }

    /**
     * @notice Check if is string is empty
     * @param _str String to check
     */
    function isStrEmpty(string memory _str) internal pure returns (bool) {
        return bytes(_str).length == 0;
    }

    // Getters

    function checkUserContactExisting(
        uint256 _contactId
    ) public view returns (bool) {
        // return contactExisting[_contactId];
        return userContactExists[msg.sender][_contactId];
    }

    function getContacts() public view returns (Contact[] memory) {
        return userContacts[msg.sender];
    }
}
