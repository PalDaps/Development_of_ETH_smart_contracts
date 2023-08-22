// SPDX-License-Identifier: MIT

// Как деплоить всю эту тему?
// 1. деплой Токена SiriusToken.sol
// 2. деплой governance(Нужно будет туда передать с помощью какого токена голосуем)
// 3. деплой demo

pragma solidity ^0.8.0;

// Это нужно для того, чтобы указать, что у нас будет токен с помощью которого можно голосовать
import "./DapsIERC20.sol";

contract Governance {

    // Это структура для хранения информации по конкретному голосованию
    // Сколько за и сколько против
    // Также эти данные можно хранить и в Proposal, но так достигается большая гибкость
    struct ProposalVote {

        // Голоса против
        uint againstVote;

        // Голоса за
        uint forVotes;

        // Голоса воздержавшихся
        uint abstainVotes;

        // Также информация о том, кто уже проголосовал
        mapping(address => bool) hasVoted;
    }


    struct Proposal {

        // Когда голосование по предложению начинается
        uint votingStarts;

        // Когда голосование по предложению закончилось
        uint votingEnds;

        // Было это предложение выполнена или нет
        bool executed; 
    }

    // Токен, который реализует IERC20
    IERC20 public token;

    // Информация о том, что у каждого Id предложения есть Proposal
    mapping(bytes32 => Proposal) public proposals;

    // Информация о том, что у каждого Id предложения есть ProposalVote
    mapping(bytes32 => ProposalVote) public proposalVotes;

    // Для необходимости сделаем констату для DELAY
    uint public constant VOTING_DELAY = 10;

    // Сколько должно идти голосование
    uint public constant VOTING_DURATION = 60;

    // Описываем какие состояния могут быть у предложения
    // Pending - Голосования еще не началось
    // Active - голосование идет
    // Successeded - голосование успешно завершилось
    // Defeated - предложения не прошло
    // Executed - предложение осуществлено
    enum ProposalState {Pending, Active, Successeded, Defeated, Executed}

    // В конструкторе мы говорим, что вот такой токен нам нужно использовать для голосования
    constructor(IERC20 _token) {
        token = _token;
    }

    // Функция для того, чтобы предлагать новую инициативу(новую транзакцию) для выполнения
    // _to - цель. Куда мы все отправляем
    // _value - средства, которые мы хотим отправить
    // _func - функция, которую мы хотим вызвать
    // _data - данные, которые мы хотим отправлять
    // _description - для каждого предложения нужно обьяснение 
    function propose(address _to, uint _value, string calldata _func, bytes calldata _data, string calldata _description) external returns(bytes32){

        // Проверяем, что только тот человек, который обладает токенами может выдвигать инициативы
        require(token.balanceOf(msg.sender) > 0, "Daps: not enough token");

        // Теперь нужно сгенерировать уникальный идентификатор
        // По этому Id мы будем понимать за какое предложение мы голосуем
        // Так как _description может быть большим, то мы сразу считаем хеш от этого значения
        bytes32 proposalId = generateProposalId(_to, _value, _func, _data, keccak256(bytes(_description)));

        // Проверяем, Что такого предложения еще нет
        // Типо не должно быть ситуации, что нам предлагается абсолютная два одинаковых предложения
        require(proposals[proposalId].votingStarts == 0, "Daps: proposal already exists");

        // Новое предложение 
        proposals[proposalId] = Proposal({
            
            // То есть как только отправляется транзакция, сразу начинается во время голосования или с каким-то DELAY
            votingStarts: block.timestamp + VOTING_DELAY,

            // А заканчивается
            votingEnds: block.timestamp + VOTING_DELAY + VOTING_DURATION,

            executed: false
        });

        return proposalId;
    }

    // Непосредтсвенно функция для описания самого голосования
    function vote(bytes32 proposalId, uint8 voteType) external {

        // проверяем что голосвание началось
        // то есть только для активного предложения можно оставлять свой голос
        require(state(proposalId) == ProposalState.Active, "Daps: invalid state");

        // Смотрим у кого токенов больше
        // И эта очень простая реализация, есть намного сложнее
        uint votingPower = token.balanceOf(msg.sender);

        require(votingPower > 0, "Daps: not enough tokens");

        // Теперь нужно найти пропосал по Id и за него оставить голос
        ProposalVote storage proposalVote = proposalVotes[proposalId];

        // Cмотрим не голосовал ли еще msg.sender?
        require(!proposalVote.hasVoted[msg.sender], "Daps: already voted");

        // Ну смотрим за что, Хочет голосовать тело
        if (voteType == 0) {
            proposalVote.againstVote += votingPower;
        } else if (voteType == 1) {
            proposalVote.forVotes += votingPower;
        } else {
            proposalVote.abstainVotes += votingPower;
        }

        // Теперь устанавливаем голос msg.sender
        proposalVote.hasVoted[msg.sender] = true;

    }

    // Также очень важно проверить, что голос находится в правильном состоянии.
    // Возвращаем состояние ProposalState это enum
    function state(bytes32 proposalId) public view returns(ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        ProposalVote storage proposalVote = proposalVotes[proposalId];

        // Проверяем есть ли такой пропосал вообще?
        require(proposal.votingStarts > 0, "Daps: proposal does not exist");

        // Когда предложение уже осущетсвлено, тогда возвращаем executed
        if (proposal.executed) {
            return ProposalState.Executed;
        }

        // Голосование ожидается
        if (block.timestamp < proposal.votingStarts) {
            return ProposalState.Pending;
        }

        // Если голосование идет, но еще не кончилось
        if (block.timestamp >= proposal.votingStarts && proposal.votingEnds > block.timestamp) {
            return ProposalState.Active;
        }

        // Голосование закончилось или уже голоса набраны. Или голоса не набраны
        if (proposalVote.forVotes > proposalVote.againstVote) {
            return ProposalState.Successeded;
        } else {
            return ProposalState.Defeated;
        }

    }

    // Функция, которая выполняет предложение
    function execute(address _to, uint _value, string calldata _func, bytes calldata _data, bytes32 _descriptionHash) external returns(bytes memory){
        
        // Нужно заново сгенерировать proposalId на основе всех входных данных, чтобы удостовериться, что то, что мы
        // пытаемся сейчас выполнить действительно по нему прошло голосование, что такой proposal существует
        bytes32 proposalId = generateProposalId(_to, _value, _func, _data, _descriptionHash); 

        // А дальше проверяем, что данный proposal находится в правильно состоянии
        // то есть за него прошло голосование
        require(state(proposalId) == ProposalState.Successeded, "Daps: invalid state");

        // Теперь достаем это пропозал 
        Proposal storage proposal = proposals[proposalId];

        // Говорим, что что предложение осуществлено
        proposal.executed = true;

        // Перед тем как выполнить пропосал нам нужно закодировать данные
        bytes memory data;

        // Если название фукнции есть, То
        if (bytes(_func).length > 0) {
            // Взять 4 байта хеша названия и добавить туда _data
            data = abi.encodePacked(bytes4(keccak256(bytes(_func))), _data);
        } else {

            // Если берем просто данные
            data = _data;
        }

        // А дальше нам остается его выполнить
        // И считваем информацию в bool success и resp
        (bool success, bytes memory resp) = _to.call{value : _value}(data);

        require(success, "Daps: TX failed");
        return resp;

    }

    // Теперь описываем функцию generateProposalId()
    function generateProposalId(address _to, uint _value, string calldata _func, bytes calldata _data, bytes32 _descriptionHash) internal pure returns(bytes32) {
        return keccak256(abi.encode(_to, _value, _func, _data, _descriptionHash));
    }

}