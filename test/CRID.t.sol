// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../contracts/CRID.sol";
import {RegistroDisciplinas} from "../contracts/CRID.sol";
// import { RegistroDisciplinas.Inscricao } from "../contracts/CRID.sol"; // Importa o struct

contract RegistroDisciplinasRoteiroTest is Test {
    RegistroDisciplinas public registroDisciplinas;
    address public owner;
    address public alunoTeste; // Usaremos este como o aluno principal para os testes

    // Nomes e códigos de disciplina para fácil referência
    string public NOME_CALCULO1 = "Calculo 1";
    string public COD_CALCULO1 = "COD110";
    string public PROF_MARCELO = "Marcelo";
    string public STATUS_NORMAL = "Inscricao Normal";

    string public NOME_CALCULO2 = "Calculo 2";
    string public COD_CALCULO2 = "COD120";
    string public PROF_MONICA = "Monica";
    string public STATUS_PENDENTE = "Inscricao Pendente"; // Novo status para teste

    string public NOME_CALCULO3 = "Calculo 3";
    string public COD_CALCULO3 = "COD130";
    string public PROF_ANATOLI = "Anatoli";

    // O período corrente será definido no construtor do contrato no setUp
    string public PERIODO_CORRENTE = "2025.1";

    // `setUp()` é executado antes de cada teste
    function setUp() public {
        owner = makeAddr("owner_secretario");
        alunoTeste = makeAddr("aluno_de_teste"); // Endereço para o aluno

        // Secretário inicializa o contrato com o período corrente 2025.1
        vm.startPrank(owner);
        registroDisciplinas = new RegistroDisciplinas(PERIODO_CORRENTE);
        vm.stopPrank();
    }

    // --- Teste Principal do Roteiro ---
    function testRoteiroCompletoInscricoes() public {
        // --- 1. Adicionar 3 disciplinas para o aluno ---

        vm.startPrank(owner); // Secretário realiza as inscrições
        registroDisciplinas.inscreverAluno(alunoTeste, NOME_CALCULO1, COD_CALCULO1, PROF_MARCELO, STATUS_NORMAL);
        registroDisciplinas.inscreverAluno(alunoTeste, NOME_CALCULO2, COD_CALCULO2, PROF_MONICA, STATUS_NORMAL);
        registroDisciplinas.inscreverAluno(alunoTeste, NOME_CALCULO3, COD_CALCULO3, PROF_ANATOLI, STATUS_NORMAL);
        vm.stopPrank();

        // --- 2. Realizar um getInscricoesAlunoPorPeriodo e validar se elas estão todas aqui ---

        RegistroDisciplinas.Inscricao[] memory inscricoes =
            registroDisciplinas.getInscricoesAlunoPorPeriodo(alunoTeste, PERIODO_CORRENTE);

        // Validar o número total de inscrições
        assertEq(inscricoes.length, 3, "Deve haver 3 inscricoes para o aluno.");

        // Validar os detalhes de cada inscrição
        // Como a ordem pode variar com push/pop, vamos verificar se todas estão presentes
        // e, em seguida, validar o conteúdo. Uma forma de fazer isso é iterar
        // ou usar um helper se a lista for muito grande. Para 3, podemos ser explícitos.
        bool calc1Found = false;
        bool calc2Found = false;
        bool calc3Found = false;

        for (uint256 i = 0; i < inscricoes.length; i++) {
            if (
                keccak256(abi.encodePacked(inscricoes[i].codigoDisciplina)) == keccak256(abi.encodePacked(COD_CALCULO1))
            ) {
                assertEq(inscricoes[i].nomeDisciplina, NOME_CALCULO1);
                assertEq(inscricoes[i].nomeProfessor, PROF_MARCELO);
                assertEq(inscricoes[i].statusInscricao, STATUS_NORMAL);
                calc1Found = true;
            } else if (
                keccak256(abi.encodePacked(inscricoes[i].codigoDisciplina)) == keccak256(abi.encodePacked(COD_CALCULO2))
            ) {
                assertEq(inscricoes[i].nomeDisciplina, NOME_CALCULO2);
                assertEq(inscricoes[i].nomeProfessor, PROF_MONICA);
                assertEq(inscricoes[i].statusInscricao, STATUS_NORMAL);
                calc2Found = true;
            } else if (
                keccak256(abi.encodePacked(inscricoes[i].codigoDisciplina)) == keccak256(abi.encodePacked(COD_CALCULO3))
            ) {
                assertEq(inscricoes[i].nomeDisciplina, NOME_CALCULO3);
                assertEq(inscricoes[i].nomeProfessor, PROF_ANATOLI);
                assertEq(inscricoes[i].statusInscricao, STATUS_NORMAL);
                calc3Found = true;
            }
        }
        assertTrue(calc1Found, "Calculo 1 deve estar presente.");
        assertTrue(calc2Found, "Calculo 2 deve estar presente.");
        assertTrue(calc3Found, "Calculo 3 deve estar presente.");

        // --- 3. Em seguida realizar uma alteração no status de Calculo 2 para "Inscricao Pendente" ---

        vm.startPrank(owner); // Secretário altera o status
        registroDisciplinas.alterarStatusInscricao(alunoTeste, COD_CALCULO2, STATUS_PENDENTE);
        vm.stopPrank();

        // Verificar o status atualizado de Calculo 2
        inscricoes = registroDisciplinas.getInscricoesAlunoPorPeriodo(alunoTeste, PERIODO_CORRENTE);
        for (uint256 i = 0; i < inscricoes.length; i++) {
            if (
                keccak256(abi.encodePacked(inscricoes[i].codigoDisciplina)) == keccak256(abi.encodePacked(COD_CALCULO2))
            ) {
                assertEq(
                    inscricoes[i].statusInscricao, STATUS_PENDENTE, "Status de Calculo 2 deve ser 'Inscricao Pendente'."
                );
                break;
            }
        }

        // --- 4. Por fim, deletar Calculo 3 da crid ---

        vm.startPrank(owner); // Secretário remove a inscrição
        registroDisciplinas.removerInscricao(alunoTeste, COD_CALCULO3);
        vm.stopPrank();

        // --- 5. Realizar um get e verificar se está tudo certo ---

        inscricoes = registroDisciplinas.getInscricoesAlunoPorPeriodo(alunoTeste, PERIODO_CORRENTE);

        // Validar o número total de inscrições após a remoção
        assertEq(inscricoes.length, 2, "Deve haver 2 inscricoes apos a remocao de Calculo 3.");

        // Validar que Calculo 3 não está mais presente e que as outras estão
        bool calc1StillThere = false;
        bool calc2StillThere = false;
        bool calc3Gone = true; // Assume que foi removido

        for (uint256 i = 0; i < inscricoes.length; i++) {
            if (
                keccak256(abi.encodePacked(inscricoes[i].codigoDisciplina)) == keccak256(abi.encodePacked(COD_CALCULO1))
            ) {
                assertEq(inscricoes[i].nomeDisciplina, NOME_CALCULO1);
                assertEq(inscricoes[i].nomeProfessor, PROF_MARCELO);
                assertEq(inscricoes[i].statusInscricao, STATUS_NORMAL); // Status original
                calc1StillThere = true;
            } else if (
                keccak256(abi.encodePacked(inscricoes[i].codigoDisciplina)) == keccak256(abi.encodePacked(COD_CALCULO2))
            ) {
                assertEq(inscricoes[i].nomeDisciplina, NOME_CALCULO2);
                assertEq(inscricoes[i].nomeProfessor, PROF_MONICA);
                assertEq(inscricoes[i].statusInscricao, STATUS_PENDENTE); // Status alterado
                calc2StillThere = true;
            } else if (
                keccak256(abi.encodePacked(inscricoes[i].codigoDisciplina)) == keccak256(abi.encodePacked(COD_CALCULO3))
            ) {
                calc3Gone = false; // Se encontrarmos, algo deu errado
            }
        }
        assertTrue(calc1StillThere, "Calculo 1 ainda deve estar presente.");
        assertTrue(calc2StillThere, "Calculo 2 ainda deve estar presente.");
        assertTrue(calc3Gone, "Calculo 3 deve ter sido removido.");
    }
}
