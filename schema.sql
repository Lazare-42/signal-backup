--
-- PostgreSQL database dump
--

-- Dumped from database version 14.17 (Homebrew)
-- Dumped by pg_dump version 14.17 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: messages_search_vector_update(); Type: FUNCTION; Schema: public; Owner: lazsofra
--

CREATE FUNCTION public.messages_search_vector_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.content::text, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.sender::text, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(NEW.recipients::text, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(NEW.metadata::text, '')), 'D');
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.messages_search_vector_update() OWNER TO lazsofra;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: lazsofra
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO lazsofra;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: contacts; Type: TABLE; Schema: public; Owner: lazsofra
--

CREATE TABLE public.contacts (
    contact_id text NOT NULL,
    display_name text,
    phone_number text,
    email text,
    discord_id text,
    telegram_id text,
    signal_id text,
    whatsapp_id text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.contacts OWNER TO lazsofra;

--
-- Name: message_tags; Type: TABLE; Schema: public; Owner: lazsofra
--

CREATE TABLE public.message_tags (
    message_id text NOT NULL,
    tag text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.message_tags OWNER TO lazsofra;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: lazsofra
--

CREATE TABLE public.messages (
    message_id text NOT NULL,
    platform text NOT NULL,
    sender jsonb NOT NULL,
    recipients jsonb NOT NULL,
    content jsonb NOT NULL,
    metadata jsonb NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    received_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    search_vector tsvector
);


ALTER TABLE public.messages OWNER TO lazsofra;

--
-- Name: webhook_deliveries; Type: TABLE; Schema: public; Owner: lazsofra
--

CREATE TABLE public.webhook_deliveries (
    id integer NOT NULL,
    message_id text,
    platform text NOT NULL,
    webhook_url text NOT NULL,
    status text NOT NULL,
    attempt_count integer DEFAULT 0,
    last_attempt_at timestamp with time zone,
    delivered_at timestamp with time zone,
    error_message text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.webhook_deliveries OWNER TO lazsofra;

--
-- Name: webhook_deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: lazsofra
--

CREATE SEQUENCE public.webhook_deliveries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.webhook_deliveries_id_seq OWNER TO lazsofra;

--
-- Name: webhook_deliveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lazsofra
--

ALTER SEQUENCE public.webhook_deliveries_id_seq OWNED BY public.webhook_deliveries.id;


--
-- Name: webhook_deliveries id; Type: DEFAULT; Schema: public; Owner: lazsofra
--

ALTER TABLE ONLY public.webhook_deliveries ALTER COLUMN id SET DEFAULT nextval('public.webhook_deliveries_id_seq'::regclass);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: lazsofra
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (contact_id);


--
-- Name: message_tags message_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: lazsofra
--

ALTER TABLE ONLY public.message_tags
    ADD CONSTRAINT message_tags_pkey PRIMARY KEY (message_id, tag);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: lazsofra
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- Name: webhook_deliveries webhook_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: lazsofra
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_pkey PRIMARY KEY (id);


--
-- Name: idx_contacts_discord_id; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_contacts_discord_id ON public.contacts USING btree (discord_id) WHERE (discord_id IS NOT NULL);


--
-- Name: idx_contacts_email; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_contacts_email ON public.contacts USING btree (email) WHERE (email IS NOT NULL);


--
-- Name: idx_contacts_phone_number; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_contacts_phone_number ON public.contacts USING btree (phone_number) WHERE (phone_number IS NOT NULL);


--
-- Name: idx_contacts_signal_id; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_contacts_signal_id ON public.contacts USING btree (signal_id) WHERE (signal_id IS NOT NULL);


--
-- Name: idx_contacts_telegram_id; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_contacts_telegram_id ON public.contacts USING btree (telegram_id) WHERE (telegram_id IS NOT NULL);


--
-- Name: idx_contacts_whatsapp_id; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_contacts_whatsapp_id ON public.contacts USING btree (whatsapp_id) WHERE (whatsapp_id IS NOT NULL);


--
-- Name: idx_message_tags_message_id; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_message_tags_message_id ON public.message_tags USING btree (message_id);


--
-- Name: idx_message_tags_tag; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_message_tags_tag ON public.message_tags USING btree (tag);


--
-- Name: idx_messages_created_at; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_created_at ON public.messages USING btree (created_at DESC);


--
-- Name: idx_messages_platform; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_platform ON public.messages USING btree (platform);


--
-- Name: idx_messages_platform_timestamp; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_platform_timestamp ON public.messages USING btree (platform, "timestamp" DESC);


--
-- Name: idx_messages_received_at; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_received_at ON public.messages USING btree (received_at DESC);


--
-- Name: idx_messages_recipients; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_recipients ON public.messages USING gin (recipients);


--
-- Name: idx_messages_search_vector; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_search_vector ON public.messages USING gin (search_vector);


--
-- Name: idx_messages_sender_contact_id; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_sender_contact_id ON public.messages USING btree (((sender ->> 'contactId'::text)));


--
-- Name: idx_messages_timestamp; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_messages_timestamp ON public.messages USING btree ("timestamp" DESC);


--
-- Name: idx_webhook_deliveries_message_id; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_webhook_deliveries_message_id ON public.webhook_deliveries USING btree (message_id);


--
-- Name: idx_webhook_deliveries_platform; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_webhook_deliveries_platform ON public.webhook_deliveries USING btree (platform);


--
-- Name: idx_webhook_deliveries_retry; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_webhook_deliveries_retry ON public.webhook_deliveries USING btree (status, last_attempt_at) WHERE ((status = 'pending'::text) OR (status = 'failed'::text));


--
-- Name: idx_webhook_deliveries_status; Type: INDEX; Schema: public; Owner: lazsofra
--

CREATE INDEX idx_webhook_deliveries_status ON public.webhook_deliveries USING btree (status);


--
-- Name: messages messages_search_vector_trigger; Type: TRIGGER; Schema: public; Owner: lazsofra
--

CREATE TRIGGER messages_search_vector_trigger BEFORE INSERT OR UPDATE OF content, sender, recipients, metadata ON public.messages FOR EACH ROW EXECUTE FUNCTION public.messages_search_vector_update();


--
-- Name: contacts update_contacts_updated_at; Type: TRIGGER; Schema: public; Owner: lazsofra
--

CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: messages update_messages_updated_at; Type: TRIGGER; Schema: public; Owner: lazsofra
--

CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: webhook_deliveries update_webhook_deliveries_updated_at; Type: TRIGGER; Schema: public; Owner: lazsofra
--

CREATE TRIGGER update_webhook_deliveries_updated_at BEFORE UPDATE ON public.webhook_deliveries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: message_tags message_tags_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lazsofra
--

ALTER TABLE ONLY public.message_tags
    ADD CONSTRAINT message_tags_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(message_id) ON DELETE CASCADE;


--
-- Name: webhook_deliveries webhook_deliveries_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lazsofra
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(message_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

