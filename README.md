# 📚 Biblioteca Digital - Sistema de Gerenciamento

Um sistema web simples e direto focado na modernização do controle interno de uma biblioteca municipal, substituindo o uso de planilhas por uma plataforma centralizada para controle de acervo, leitores e empréstimos.

[![Documentação Técnica](https://img.shields.io/badge/Documentação-Google_Docs-4285F4?style=for-the-badge&logo=googledocs&logoColor=white)](https://docs.google.com/document/d/1TgZUdkXb09_7coNVF0Tkivrh_RTP5Gl7AkNdB4bIEBU/edit?usp=sharing)
[![Trello](https://img.shields.io/badge/Trello-Kanban-0052CC?style=for-the-badge&logo=trello&logoColor=white)](https://trello.com/invite/b/6a329f937c5901df56fcf6ff/ATTI23ff440aee78cc79b8905fdc3ae7c58d5C5554D4/projetobibliotecamunicipal)

## 🎯 Escopo do Projeto

O projeto é estritamente focado em um CRUD completo para resolver a gestão da biblioteca, dividido em dois módulos principais:

- **Módulo Administrativo (Bibliotecários):** Gerenciamento do acervo (livros, revistas, mídias), cadastro de leitores ativos/suspensos e registro operacional de empréstimos e devoluções no balcão.
- **Portal do Leitor:** Interface web autônoma para consulta de disponibilidade de obras, reservas e renovações.

## 🛠️ Stack Tecnológica

A arquitetura adota um modelo monolítico enxuto, sem ferramentas de build pesadas no frontend, delegando as regras críticas de negócio diretamente para o banco de dados.

* **Backend:** Java com Spring Boot (API REST e Spring Data JPA).
* **Banco de Dados:** PostgreSQL (Cálculo de multas e gatilhos de bloqueio implementados via `PL/pgSQL`).
* **Frontend:** HTML5, CSS3 e Vanilla JS (Comunicação assíncrona via Fetch API).

## ⚙️ Regras de Negócio Nativas (PostgreSQL)

Para garantir a integridade dos dados sem sobrecarregar o backend com validações redundantes, as seguintes regras operam diretamente no SGBD via *Triggers* e *Stored Procedures*:
* Bloqueio automático de novos empréstimos para leitores inadimplentes ou com limite de obras excedido (máximo de 3).
* Cálculo diário de multas para devoluções realizadas após o prazo previsto.
* Proteção contra exclusão física (*Hard Delete*) de registros com histórico de movimentação.

## 🚀 Como Executar

*(Instruções de clonagem, configuração das credenciais do banco no `application.properties` e execução do Spring Boot via terminal devem ser inseridas aqui após o primeiro deploy local).*





