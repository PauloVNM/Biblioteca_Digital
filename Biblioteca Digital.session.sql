-- 1. Criação das Tabelas

CREATE TABLE reader (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    cpf VARCHAR(14) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED'))
);

CREATE TABLE item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    author VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('BOOK', 'MAGAZINE', 'MEDIA')),
    status VARCHAR(20) DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'BORROWED', 'MAINTENANCE'))
);

CREATE TABLE loan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reader_id UUID NOT NULL REFERENCES reader(id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES item(id) ON DELETE RESTRICT,
    loan_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    return_date DATE
);

CREATE TABLE fine (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID UNIQUE NOT NULL REFERENCES loan(id) ON DELETE RESTRICT,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID'))
);


-- 2. Regras de Negócio Nativas (Procedures e Triggers)

-- -----------------------------------------------------------------------------------
-- Função: Validações antes de registrar um empréstimo (RN01, RN02, RN03)
-- -----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_loan_validity()
RETURNS TRIGGER AS $$
DECLARE
    v_reader_status VARCHAR;
    v_active_loans INT;
    v_item_status VARCHAR;
BEGIN
    -- RN03: Verifica se o Leitor está suspenso
    SELECT status INTO v_reader_status FROM reader WHERE id = NEW.reader_id;
    IF v_reader_status = 'SUSPENDED' THEN
        RAISE EXCEPTION 'Loan rejected: Reader % is suspended.', NEW.reader_id;
    END IF;

    -- RN02: Verifica se o Leitor já atingiu o limite de 3 empréstimos ativos
    SELECT COUNT(*) INTO v_active_loans FROM loan WHERE reader_id = NEW.reader_id AND return_date IS NULL;
    IF v_active_loans >= 3 THEN
        RAISE EXCEPTION 'Loan rejected: Reader % has reached the limit of 3 active loans.', NEW.reader_id;
    END IF;

    -- RN01: Verifica se a obra está disponível (Utilizando trava de linha FOR UPDATE para concorrência)
    SELECT status INTO v_item_status FROM item WHERE id = NEW.item_id FOR UPDATE;
    IF v_item_status != 'AVAILABLE' THEN
        RAISE EXCEPTION 'Loan rejected: Item % is not available (Current status: %).', NEW.item_id, v_item_status;
    END IF;

    -- Tudo certo: Altera o status físico do item para emprestado
    UPDATE item SET status = 'BORROWED' WHERE id = NEW.item_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_loan_validity
BEFORE INSERT ON loan
FOR EACH ROW EXECUTE FUNCTION check_loan_validity();


-- -----------------------------------------------------------------------------------
-- Função: Executada na devolução do item (RN04, UC08)
-- -----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION process_item_return()
RETURNS TRIGGER AS $$
DECLARE
    v_overdue_days INT;
    v_fine_rate DECIMAL(10,2) := 2.00; -- Taxa diária fixa para atraso
    v_fine_amount DECIMAL(10,2);
BEGIN
    -- Intercepta apenas o evento de devolução (quando o return_date é preenchido)
    IF NEW.return_date IS NOT NULL AND OLD.return_date IS NULL THEN
        
        -- Devolve a obra fisicamente ao acervo
        UPDATE item SET status = 'AVAILABLE' WHERE id = NEW.item_id;

        -- RN04: Valida se houve atraso e processa a multa
        IF NEW.return_date > NEW.due_date THEN
            v_overdue_days := NEW.return_date - NEW.due_date;
            v_fine_amount := v_overdue_days * v_fine_rate;

            -- Insere o registro de multa associado a este empréstimo
            INSERT INTO fine (loan_id, amount, status)
            VALUES (NEW.id, v_fine_amount, 'PENDING');
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_process_item_return
BEFORE UPDATE ON loan
FOR EACH ROW EXECUTE FUNCTION process_item_return();


-- -----------------------------------------------------------------------------------
-- Função: Bloqueio automático do leitor (UC09)
-- -----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION block_reader_on_fine()
RETURNS TRIGGER AS $$
DECLARE
    v_reader_id UUID;
BEGIN
    -- Recupera o ID do leitor a partir da tabela de empréstimos
    SELECT reader_id INTO v_reader_id FROM loan WHERE id = NEW.loan_id;
    
    -- Altera o status do leitor para SUSPENSO
    UPDATE reader SET status = 'SUSPENDED' WHERE id = v_reader_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_block_reader_on_fine
AFTER INSERT ON fine
FOR EACH ROW EXECUTE FUNCTION block_reader_on_fine();