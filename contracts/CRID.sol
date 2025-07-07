// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

contract RegistroDisciplinas {
    address public owner; // O secretário do departamento
    string public periodo_corrente;

    // --- Struct para Inscrição de um aluno em uma disciplina para um período
    struct Inscricao {
        string nomeDisciplina;   // Nome da disciplina (ex: "Matemática Básica")
        string codigoDisciplina; // Código da disciplina (ex: "MAT101")
        string nomeProfessor;    // Nome do professor
        string statusInscricao;  // Status da inscrição (ex: "Ativa", "Trancada", "Cancelada")
        uint timestampInscricao; // Quando a inscrição foi feita
    }

    // Mapeamento: Endereço do Aluno -> Período (string) -> Lista de Inscrições (a CRID do aluno para o período)
    mapping(address => mapping(string => Inscricao[])) public inscricoesAlunosPorPeriodo;

    // --- Eventos ---
    event AlunoInscrito(
        address indexed aluno,
        string indexed codigoDisciplina,
        string nomeDisciplina,
        string nomeProfessor
    );
    event StatusInscricaoAlterado(
        address indexed aluno,
        string indexed codigoDisciplina,
        string antigoStatus,
        string novoStatus
    );
    event PeriodoCorrenteAlterado(string antigoPeriodo, string novoPeriodo, address indexed alteradoPor);
    event InscricaoRemovida( // Novo evento para quando uma inscrição é removida
        address indexed aluno,
        string indexed codigoDisciplina,
        string periodo,
        address indexed removidoPor
    );

    // --- Erros Personalizados ---
    error ApenasOwner();
    error JaInscrito(address aluno, string codigoDisciplina, string periodo);
    error InscricaoNaoEncontrada(address aluno, string codigoDisciplina, string periodo);
    error StatusInvalido(string status);

    // --- Construtor ---
    constructor(string memory _periodoInicial) {
        owner = msg.sender;
        require(bytes(_periodoInicial).length > 0, "Periodo inicial nao pode ser vazio");
        periodo_corrente = _periodoInicial;
    }

    // --- Modificador para restringir funções apenas ao owner ---
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ApenasOwner();
        }
        _;
    }
    // Apenas o secretário pode chamar esta função
    function setPeriodoCorrente(string memory _novoPeriodo) public onlyOwner {
        string memory antigoPeriodo = periodo_corrente;
        periodo_corrente = _novoPeriodo;
        emit PeriodoCorrenteAlterado(antigoPeriodo, _novoPeriodo, msg.sender);
    }

    // --- Função para inscrever um aluno em uma disciplina para um período --
    function inscreverAluno(
        address _aluno,
        string memory _nomeDisciplina,
        string memory _codigoDisciplina,
        string memory _nomeProfessor,
        string memory _statusInicial
    ) public onlyOwner {
        for (uint i = 0; i < inscricoesAlunosPorPeriodo[_aluno][periodo_corrente].length; i++) {
            if (
                keccak256(abi.encodePacked(inscricoesAlunosPorPeriodo[_aluno][periodo_corrente][i].codigoDisciplina)) ==
                keccak256(abi.encodePacked(_codigoDisciplina))
            ) {
                revert JaInscrito(_aluno, _codigoDisciplina, periodo_corrente);
            }
        }

        inscricoesAlunosPorPeriodo[_aluno][periodo_corrente].push(
            Inscricao({
                nomeDisciplina: _nomeDisciplina,
                codigoDisciplina: _codigoDisciplina,
                nomeProfessor: _nomeProfessor,
                statusInscricao: _statusInicial,
                timestampInscricao: block.timestamp
            })
        );

        emit AlunoInscrito(_aluno, _codigoDisciplina, _nomeDisciplina, _nomeProfessor);
    }

    function alterarStatusInscricao(
        address _aluno,
        string memory _codigoDisciplina,
        string memory _novoStatus
    ) public onlyOwner {
        bool encontrada = false;
        string memory antigoStatus;

        // Itera sobre as inscrições do aluno para o período para encontrar a disciplina
        for (uint i = 0; i < inscricoesAlunosPorPeriodo[_aluno][periodo_corrente].length; i++) {
            if (
                keccak256(abi.encodePacked(inscricoesAlunosPorPeriodo[_aluno][periodo_corrente][i].codigoDisciplina)) ==
                keccak256(abi.encodePacked(_codigoDisciplina))
            ) {
                antigoStatus = inscricoesAlunosPorPeriodo[_aluno][periodo_corrente][i].statusInscricao;
                inscricoesAlunosPorPeriodo[_aluno][periodo_corrente][i].statusInscricao = _novoStatus;
                encontrada = true;
                break;
            }
        }

        if (!encontrada) {
            revert InscricaoNaoEncontrada(_aluno, _codigoDisciplina, periodo_corrente);
        }

        emit StatusInscricaoAlterado(_aluno, _codigoDisciplina, antigoStatus, _novoStatus);
    }

function removerInscricao(
        address _aluno,
        string memory _codigoDisciplina
    ) public onlyOwner {
        Inscricao[] storage alunoInscricoesPeriodo = inscricoesAlunosPorPeriodo[_aluno][periodo_corrente];
        bool encontrada = false;

        // Percorre o array para encontrar a inscrição a ser removida
        for (uint i = 0; i < alunoInscricoesPeriodo.length; i++) {
            if (
                keccak256(abi.encodePacked(alunoInscricoesPeriodo[i].codigoDisciplina)) ==
                keccak256(abi.encodePacked(_codigoDisciplina))
            ) {
                // Encontrado! Agora, remova usando o padrão "swap and pop"
                alunoInscricoesPeriodo[i] = alunoInscricoesPeriodo[alunoInscricoesPeriodo.length - 1];
                alunoInscricoesPeriodo.pop();
                encontrada = true;
                break;
            }
        }

        if (!encontrada) {
            revert InscricaoNaoEncontrada(_aluno, _codigoDisciplina, periodo_corrente);
        }

        emit InscricaoRemovida(_aluno, _codigoDisciplina, periodo_corrente, msg.sender);
    }

    function getInscricoesAlunoPorPeriodo(address _aluno, string memory _periodo) public view returns (Inscricao[] memory) {
        return inscricoesAlunosPorPeriodo[_aluno][_periodo];
    }
}