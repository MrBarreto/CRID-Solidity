// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

contract RegistroDisciplinas {
    address public owner; // O secretário do departamento

    // --- Structs Existentes ---
    struct Disciplina {
        string nome;
        string codigo;
        address professor;
        string status;
    }

    // --- Nova Struct para Inscrição ---
    struct Inscricao {
        string codigoDisciplina;
        string periodo;
        uint timestampInscricao;
    }

    // --- Mapeamentos Existentes ---
    mapping(string => Disciplina) public crid; 

    // --- Novo Mapeamento para Inscrições de Alunos ---
    // Mapeamento: Endereço do Aluno -> Período (string) -> Lista de Inscrições
    mapping(address => mapping(string => Inscricao[])) public inscricoesAlunosPorPeriodo;

    // --- Eventos Existentes ---
    event DisciplinaAdicionada(string indexed codigo, string nome, address professor);
    event StatusDisciplinaAlterado(string indexed codigo, bool novoStatus);
    event ProfessorDisciplinaAlterado(string indexed codigo, address antigoProfessor, address novoProfessor);

    // --- Novos Eventos de Inscrição ---
    event AlunoInscrito(address indexed aluno, string indexed codigoDisciplina, string periodo);
    event InscricaoAtualizada(address indexed aluno, string indexed codigoDisciplina, string periodo, bool novoStatus);

    // --- Erros Existentes ---
    error ApenasOwner();
    error DisciplinaJaExiste(string codigo);
    error DisciplinaNaoEncontrada(string codigo);

    // --- Novos Erros de Inscrição ---
    error DisciplinaNaoAtiva(string codigo);
    error JaInscrito(address aluno, string codigoDisciplina, string periodo);
    error NaoInscrito(address aluno, string codigoDisciplina, string periodo);


    // --- Construtor e Modificador (como no código anterior) ---
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ApenasOwner();
        }
        _;
    }

    // --- Funções de Gerenciamento de Disciplinas (como no código anterior) ---
    function adicionarDisciplina(string memory _nome, string memory _codigo, address _professor) public onlyOwner {
        if (bytes(crid[_codigo].codigo).length != 0) {
            revert DisciplinaJaExiste(_codigo);
        }
        crid[_codigo] = Disciplina(_nome, _codigo, _professor, true);
        emit DisciplinaAdicionada(_codigo, _nome, _professor);
    }

    function alterarStatusDisciplina(string memory _codigo, bool _novoStatus) public onlyOwner {
        if (bytes(crid[_codigo].codigo).length == 0) {
            revert DisciplinaNaoEncontrada(_codigo);
        }
        crid[_codigo].ativa = _novoStatus;
        emit StatusDisciplinaAlterado(_codigo, _novoStatus);
    }

    function alterarProfessorDisciplina(string memory _codigo, address _novoProfessor) public onlyOwner {
        if (bytes(crid[_codigo].codigo).length == 0) {
            revert DisciplinaNaoEncontrada(_codigo);
        }
        address antigoProfessor = crid[_codigo].professor;
        crid[_codigo].professor = _novoProfessor;
        emit ProfessorDisciplinaAlterado(_codigo, antigoProfessor, _novoProfessor);
    }

    function getDisciplina(string memory _codigo) public view returns (string memory nome, string memory codigo, address professor, bool ativa) {
        Disciplina storage disciplina = crid[_codigo];
        return (disciplina.nome, disciplina.codigo, disciplina.professor, disciplina.ativa);
    }

    // --- Novas Funções para Inscrição de Alunos ---

    // Função para um aluno se inscrever em uma disciplina
    // Ou o secretário pode chamar isso para inscrever um aluno (passando o _aluno)
    function inscreverAluno(address _aluno, string memory _codigoDisciplina, string memory _periodo) public {
        // Pode adicionar 'onlyOwner' aqui se apenas o secretário puder inscrever,
        // ou permitir que qualquer um (msg.sender) se inscreva para si mesmo.
        // Para o seu cenário de "aluno consulta seu crid", vamos permitir que o aluno se inscreva.
        // Se for o secretário que inscreve, o `msg.sender` seria o secretário e o `_aluno` seria o aluno.

        // 1. Verificar se a disciplina existe e está ativa
        Disciplina storage disciplina = crid[_codigoDisciplina];
        if (bytes(disciplina.codigo).length == 0) {
            revert DisciplinaNaoEncontrada(_codigoDisciplina);
        }
        if (!disciplina.ativa) {
            revert DisciplinaNaoAtiva(_codigoDisciplina);
        }

        // 2. Verificar se o aluno já está inscrito na disciplina para este período
        // OBS: Iterar sobre um array em loop pode ser caro. Para um sistema de grande escala,
        // você pode querer um mapeamento auxiliar para verificar a existência da inscrição mais rapidamente,
        // tipo: mapping(address => mapping(string => mapping(string => bool))) public alunoJaInscrito;
        // Para este exemplo, vamos iterar (ok para número limitado de inscrições por aluno/período)
        for (uint i = 0; i < inscricoesAlunosPorPeriodo[_aluno][_periodo].length; i++) {
            if (keccak256(abi.encodePacked(inscricoesAlunosPorPeriodo[_aluno][_periodo][i].codigoDisciplina)) == keccak256(abi.encodePacked(_codigoDisciplina))) {
                revert JaInscrito(_aluno, _codigoDisciplina, _periodo);
            }
        }

        // 3. Adicionar a inscrição
        inscricoesAlunosPorPeriodo[_aluno][_periodo].push(
            Inscricao({
                codigoDisciplina: _codigoDisciplina,
                periodo: _periodo,
                ativa: true,
                timestampInscricao: block.timestamp
            })
        );

        emit AlunoInscrito(_aluno, _codigoDisciplina, _periodo);
    }

    // Função para o secretário (ou o próprio aluno, se permitido) atualizar o status de uma inscrição
    function atualizarStatusInscricao(address _aluno, string memory _codigoDisciplina, string memory _periodo, bool _novoStatus) public onlyOwner {
        // Apenas o owner pode alterar o status de uma inscrição para fins de controle
        bool encontrada = false;
        for (uint i = 0; i < inscricoesAlunosPorPeriodo[_aluno][_periodo].length; i++) {
            if (keccak256(abi.encodePacked(inscricoesAlunosPorPeriodo[_aluno][_periodo][i].codigoDisciplina)) == keccak256(abi.encodePacked(_codigoDisciplina))) {
                inscricoesAlunosPorPeriodo[_aluno][_periodo][i].ativa = _novoStatus;
                encontrada = true;
                break;
            }
        }

        if (!encontrada) {
            revert NaoInscrito(_aluno, _codigoDisciplina, _periodo);
        }
        emit InscricaoAtualizada(_aluno, _codigoDisciplina, _periodo, _novoStatus);
    }

    // Função para um aluno (ou qualquer um) consultar suas inscrições para um período
    // Esta é a função que o aluno usaria para "buscar sua CRID" para um período específico
    function getInscricoesAlunoPorPeriodo(address _aluno, string memory _periodo) public view returns (Inscricao[] memory) {
        return inscricoesAlunosPorPeriodo[_aluno][_periodo];
    }
}