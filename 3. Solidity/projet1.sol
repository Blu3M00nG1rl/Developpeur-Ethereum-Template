// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    //Structures
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    struct Proposal {
        string description;
        uint256 voteCount;
    }

    //Mappings
    mapping(address => Voter) public voters;

    //Enumérations
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //Variables
    WorkflowStatus public workflow_status; //Par défaut RegisteringVoters
    Proposal[] public proposals; //Tableau des proposition des voteurs créé à partir de la structure
    uint256 winningProposalId; //Id de la proposition gagnante
    uint256 votesCount = 0; //Comptage du nombre de votes

    //Events
    event VoterRegistered(address voterAddress); //ok
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);

    //Constructor
    constructor() {
        voters[msg.sender].isRegistered = true; //ajout de l'admin au mapping voters
    }

    //Modifier check si l'utilisateur est autorisé par l'admin
    modifier checkAuthorized() {
        require(
            voters[msg.sender].isRegistered,
            unicode"Vous n'êtes pas sur la liste des utilisateurs autorisés à voter."
        );
        _;
    }

    //Fonctions

    //L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function registerVoter(address _address) public onlyOwner {
        require(
            !voters[_address].isRegistered,
            unicode"Cette personne est déjà enregistrée."
        );
        voters[_address].isRegistered = true;
        voters[_address].hasVoted = false;
        emit VoterRegistered(_address);
    }

    //L'administrateur du vote commence la session d'enregistrement de la proposition.
    function startProposal() public onlyOwner {
        emit WorkflowStatusChange(
            workflow_status,
            WorkflowStatus.ProposalsRegistrationStarted
        );
        //Nouveau Statut
        workflow_status = WorkflowStatus.ProposalsRegistrationStarted;
    }

    //Les électeurs inscrits peuvent consulter les propositions enregistrées et leur identifiant.
    function getProposals()
        external
        view
        checkAuthorized
        returns (string[] memory, uint256[] memory)
    {
        require(
            proposals.length > 0,
            unicode"Il n'y a aucune proposition enregistrée."
        );
        string[] memory props = new string[](proposals.length);
        uint256[] memory ids = new uint256[](proposals.length);
        for (uint256 i = 0; i < proposals.length; i++) {
            props[i] = proposals[i].description;
            ids[i] = i;
        }
        return (props, ids);
    }

    //Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    function registerProposal(string memory _proposal)
        external
        checkAuthorized
    {
        //Vérification statut du workflow
        require(
            workflow_status == WorkflowStatus.ProposalsRegistrationStarted,
            unicode"L'enregistrement des propositions est désactivé."
        );
        //Vérification doublons d'enregistrement
        for (uint256 i = 0; i < proposals.length; i++) {
            if (
                keccak256(abi.encodePacked(proposals[i].description)) ==
                keccak256(abi.encodePacked(_proposal))
            ) {
                revert(unicode"Cette proposition est déjà enregistrée");
            }
        }
        Proposal memory proposal = Proposal(_proposal, 0); //Variable secondaire pour alimentation du tableau proposals
        proposals.push(proposal);
        emit ProposalRegistered(proposals.length - 1);
    }

    //L'administrateur de vote met fin à la session d'enregistrement des propositions.
    function endProposal() public onlyOwner {
        emit WorkflowStatusChange(
            workflow_status,
            WorkflowStatus.ProposalsRegistrationEnded
        );
        //Nouveau Statut
        workflow_status = WorkflowStatus.ProposalsRegistrationEnded;
    }

    //L'administrateur du vote commence la session de vote.
    function startVoting() public onlyOwner {
        emit WorkflowStatusChange(
            workflow_status,
            WorkflowStatus.VotingSessionStarted
        );
        //Nouveau Statut
        workflow_status = WorkflowStatus.VotingSessionStarted;
    }

    //Les électeurs inscrits votent pour leur proposition préférée.
    function voteProposal(uint256 _proposal) external checkAuthorized {
        //Vérification statut du workflow
        require(
            workflow_status == WorkflowStatus.VotingSessionStarted,
            unicode"La période de vote est désactivée."
        );
        //Vérification que l'id est dans la liste des proposals
        require(
            _proposal >= 0 && _proposal <= proposals.length - 1,
            unicode"Ce numéro n'est pas dans la liste des propositions."
        );
        //Vérification si le voteur à déjà voté.
        require(!voters[msg.sender].hasVoted, unicode"Vous avez déjà voté.");
        //Alimentation du mapping voter
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposal;
        proposals[_proposal].voteCount += 1;
        emit Voted(msg.sender, _proposal);
    }

    //L'administrateur du vote met fin à la session de vote.
    function endVoting() public onlyOwner {
        emit WorkflowStatusChange(
            workflow_status,
            WorkflowStatus.VotingSessionEnded
        );
        //Nouveau Statut
        workflow_status = WorkflowStatus.VotingSessionEnded;
    }

    //L'administrateur du vote comptabilise les votes.
    function VotesCount() public onlyOwner returns (uint256) {
        //Vérification statut du workflow
        require(
            workflow_status == WorkflowStatus.VotingSessionEnded,
            unicode"La période de vote n'est pas clôturée."
        );
        for (uint256 i = 0; i < proposals.length; i++) {
            votesCount += proposals[i].voteCount;
        }
        emit WorkflowStatusChange(workflow_status, WorkflowStatus.VotesTallied);
        //Nouveau Statut
        workflow_status = WorkflowStatus.VotesTallied;
        return votesCount;
    }

    //Tout le monde peut vérifier les derniers détails de la proposition gagnante (première proposition ayant recueillie le plus de votes).
    function getWinner() public returns (string memory) {
        //Vérification statut du workflow
        require(
            workflow_status == WorkflowStatus.VotesTallied,
            unicode"Patience, tous les votes n'ont pas été comptabilisés."
        );
        for (uint256 i = 0; i < proposals.length; i++) {
            if (winningProposalId < proposals[i].voteCount) {
                winningProposalId = proposals[i].voteCount;
            }
        }
        return proposals[winningProposalId].description;
    }
}
