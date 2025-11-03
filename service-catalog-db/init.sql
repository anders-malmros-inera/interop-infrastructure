-- init.sql: create table for api instances and insert sample data
CREATE TABLE IF NOT EXISTS api_instances (
  id TEXT PRIMARY KEY,
  logical_address TEXT NOT NULL,
  organization_id TEXT,
  organization_name TEXT,
  interoperability_specification_id TEXT,
  api_standard TEXT,
  url TEXT,
  status TEXT,
  access_model_type TEXT,
  access_model_metadata_url TEXT,
  signature TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- sample data
INSERT INTO api_instances (id, logical_address, organization_id, organization_name, interoperability_specification_id, api_standard, url, status, access_model_type, access_model_metadata_url, signature)
VALUES (
  'sample-1', 'SE1611', 'ORG-1', 'Organisation 1', 'remissV1', 'REST', 'https://api.example.org/remiss', 'active', 'oauth2', 'https://auth.example.org/.well-known', 'sig1'
) ON CONFLICT (id) DO NOTHING;

-- Members table used by federation membership API
CREATE TABLE IF NOT EXISTS members (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
