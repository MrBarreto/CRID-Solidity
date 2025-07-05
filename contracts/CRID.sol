// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

contract RegistroDisciplinas {
    address public owner; // O secretário do departamento

    // --- Struct para Inscrição de um aluno em uma disciplina para um período
    struct Inscricao {
        string nomeDisciplina;   // Nome da disciplina (ex: "Matemática Básica")
        string codigoDisciplina; // Código da disciplina (ex: "MAT101")
        string nomeProfessor;    // Nome do professor
        string statusInscricao;  // Status da inscrição (ex: "Ativa", "Trancada", "Cancelada")
        uint timestampInscricao; // Quando a inscrição foi feita
    }

    // --- Mapeamento para Inscrições de Alunos ---
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

    // --- Erros Personalizados ---
    error ApenasOwner();
    error JaInscrito(address aluno, string codigoDisciplina, string periodo);
    error InscricaoNaoEncontrada(address aluno, string codigoDisciplina, string periodo);
    error StatusInvalido(string status);

    // --- Construtor ---
    constructor() {
        owner = msg.sender;
    }

    // --- Modificador para restringir funções apenas ao owner ---
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ApenasOwner();
        }
        _; // Continua a execução da função
    }

    // --- Função para inscrever um aluno em uma disciplina para um período ---
    // Esta função seria chamada pelo owner para registrar uma inscrição,
    // ou por um front-end representando o aluno (se não tiver onlyOwner).
    function inscreverAluno(
        address _aluno,
        string memory _nomeDisciplina,
        string memory _codigoDisciplina,
        string memory _nomeProfessor,
        string memory _periodo,
        string memory _statusInicial
    ) public onlyOwner {
        // Validar que o status inicial da inscrição é "Ativa" ou algum padrão esperado
        // Não é estritamente necessário validar aqui, mas é uma boa prática para evitar lixo de dados.

        // 1. Verificar se o aluno já está inscrito na disciplina para este período
        // OBS: Iterar sobre um array em loop pode ser caro. Para um sistema de grande escala,
        // considere um mapeamento auxiliar como:
        // mapping(address => mapping(string => mapping(string => bool))) public alunoJaInscritoNaDisciplinaPeriodo;
        // para verificações rápidas.
        for (uint i = 0; i < inscricoesAlunosPorPeriodo[_aluno][_periodo].length; i++) {
            if (
                keccak256(abi.encodePacked(inscricoesAlunosPorPeriodo[_aluno][_periodo][i].codigoDisciplina)) ==
                keccak256(abi.encodePacked(_codigoDisciplina))
            ) {
                revert JaInscrito(_aluno, _codigoDisciplina, _periodo);
            }
        }

        // 2. Adicionar a nova inscrição ao array do aluno para o período
        inscricoesAlunosPorPeriodo[_aluno][_periodo].push(
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

    // --- Função para o secretário alterar o status de uma inscrição ---
    // (ex: de "Ativa" para "Trancada" ou "Cancelada")
    function alterarStatusInscricao(
        address _aluno,
        string memory _codigoDisciplina,
        string memory _periodo,
        string memory _novoStatus
    ) public onlyOwner {
        // Validação de status: você pode adicionar uma lista de estados permitidos aqui
        // Ex: if (keccak256(abi.encodePacked(_novoStatus)) != keccak256(abi.encodePacked("Ativa")) && ...)
        // Para simplicidade, não farei essa validação extensiva, mas é recomendada.

        bool encontrada = false;
        string memory antigoStatus;

        // Itera sobre as inscrições do aluno para o período para encontrar a disciplina
        for (uint i = 0; i < inscricoesAlunosPorPeriodo[_aluno][_periodo].length; i++) {
            if (
                keccak256(abi.encodePacked(inscricoesAlunosPorPeriodo[_aluno][_periodo][i].codigoDisciplina)) ==
                keccak256(abi.encodePacked(_codigoDisciplina))
            ) {
                antigoStatus = inscricoesAlunosPorPeriodo[_aluno][_periodo][i].statusInscricao;
                inscricoesAlunosPorPeriodo[_aluno][_periodo][i].statusInscricao = _novoStatus;
                encontrada = true;
                break; // Encontrou e atualizou, pode sair do loop
            }
        }

        if (!encontrada) {
            revert InscricaoNaoEncontrada(_aluno, _codigoDisciplina, _periodo);
        }

        emit StatusInscricaoAlterado(_aluno, _codigoDisciplina, antigoStatus, _novoStatus);
    }

    // --- Função para o aluno (ou qualquer um) consultar suas inscrições para um período ---
    // Esta é a função que o aluno usaria para "buscar sua CRID" para um período específico
    function getInscricoesAlunoPorPeriodo(address _aluno, string memory _periodo) public view returns (Inscricao[] memory) {
        return inscricoesAlunosPorPeriodo[_aluno][_periodo];
    }
}