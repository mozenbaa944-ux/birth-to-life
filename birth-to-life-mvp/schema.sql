-- Birth-to-Life Medical Records System
-- Run this in Supabase SQL Editor

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Users table (auth wrapper with role)
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  role text not null check (role in ('parent', 'doctor')),
  full_name text not null,
  created_at timestamptz default now()
);

-- Parents table
create table if not exists public.parents (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  phone text,
  address text,
  emergency_contact text,
  created_at timestamptz default now()
);

-- Doctors table
create table if not exists public.doctors (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  license_number text not null unique,
  specialty text,
  hospital text,
  phone text,
  verified boolean default false,
  created_at timestamptz default now()
);

-- Children table
create table if not exists public.children (
  id uuid primary key default uuid_generate_v4(),
  child_id text not null unique default 'BTL-' || upper(substring(gen_random_uuid()::text, 1, 8)),
  parent_id uuid not null references public.parents(id) on delete cascade,
  full_name text not null,
  date_of_birth date not null,
  gender text check (gender in ('male', 'female', 'other')),
  blood_type text,
  allergies text,
  medical_notes text,
  created_at timestamptz default now()
);

-- Documents table
create table if not exists public.documents (
  id uuid primary key default uuid_generate_v4(),
  child_id uuid not null references public.children(id) on delete cascade,
  uploaded_by uuid not null references public.users(id),
  document_type text not null,
  file_name text not null,
  file_url text not null,
  file_size integer,
  description text,
  created_at timestamptz default now()
);

-- Doctor access requests
create table if not exists public.doctor_access_requests (
  id uuid primary key default uuid_generate_v4(),
  doctor_id uuid not null references public.doctors(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reason text,
  requested_at timestamptz default now(),
  responded_at timestamptz,
  unique(doctor_id, child_id)
);

-- Doctor notes
create table if not exists public.doctor_notes (
  id uuid primary key default uuid_generate_v4(),
  child_id uuid not null references public.children(id) on delete cascade,
  doctor_id uuid not null references public.doctors(id) on delete cascade,
  note_type text default 'general',
  title text not null,
  content text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Vaccinations table
create table if not exists public.vaccinations (
  id uuid primary key default uuid_generate_v4(),
  child_id uuid not null references public.children(id) on delete cascade,
  added_by uuid not null references public.users(id),
  vaccine_name text not null,
  date_administered date not null,
  dose_number integer default 1,
  administered_by text,
  batch_number text,
  next_due_date date,
  notes text,
  created_at timestamptz default now()
);

-- RLS Policies
alter table public.users enable row level security;
alter table public.parents enable row level security;
alter table public.doctors enable row level security;
alter table public.children enable row level security;
alter table public.documents enable row level security;
alter table public.doctor_access_requests enable row level security;
alter table public.doctor_notes enable row level security;
alter table public.vaccinations enable row level security;

-- Users: can read/update own record
create policy "users_own" on public.users for all using (auth.uid() = id);

-- Parents: own record
create policy "parents_own" on public.parents for all using (
  user_id = auth.uid()
);

-- Doctors: own record
create policy "doctors_own" on public.doctors for all using (
  user_id = auth.uid()
);

-- Children: parent can manage, approved doctors can read
create policy "children_parent_manage" on public.children for all using (
  parent_id in (select id from public.parents where user_id = auth.uid())
);
create policy "children_doctor_read" on public.children for select using (
  id in (
    select dar.child_id from public.doctor_access_requests dar
    join public.doctors d on d.id = dar.doctor_id
    where d.user_id = auth.uid() and dar.status = 'approved'
  )
);

-- Documents: parent can manage, approved doctors can read
create policy "documents_parent_manage" on public.documents for all using (
  child_id in (
    select c.id from public.children c
    join public.parents p on p.id = c.parent_id
    where p.user_id = auth.uid()
  )
);
create policy "documents_doctor_read" on public.documents for select using (
  child_id in (
    select dar.child_id from public.doctor_access_requests dar
    join public.doctors d on d.id = dar.doctor_id
    where d.user_id = auth.uid() and dar.status = 'approved'
  )
);

-- Access requests: doctor manages own, parent sees requests for their children
create policy "requests_doctor_manage" on public.doctor_access_requests for all using (
  doctor_id in (select id from public.doctors where user_id = auth.uid())
);
create policy "requests_parent_manage" on public.doctor_access_requests for all using (
  child_id in (
    select c.id from public.children c
    join public.parents p on p.id = c.parent_id
    where p.user_id = auth.uid()
  )
);

-- Doctor notes: doctor manages own, parent reads for their children
create policy "notes_doctor_manage" on public.doctor_notes for all using (
  doctor_id in (select id from public.doctors where user_id = auth.uid())
);
create policy "notes_parent_read" on public.doctor_notes for select using (
  child_id in (
    select c.id from public.children c
    join public.parents p on p.id = c.parent_id
    where p.user_id = auth.uid()
  )
);

-- Vaccinations: parent & approved doctors can manage
create policy "vaccinations_parent_manage" on public.vaccinations for all using (
  child_id in (
    select c.id from public.children c
    join public.parents p on p.id = c.parent_id
    where p.user_id = auth.uid()
  )
);
create policy "vaccinations_doctor_manage" on public.vaccinations for all using (
  child_id in (
    select dar.child_id from public.doctor_access_requests dar
    join public.doctors d on d.id = dar.doctor_id
    where d.user_id = auth.uid() and dar.status = 'approved'
  )
);

-- Storage bucket for documents
insert into storage.buckets (id, name, public) values ('medical-documents', 'medical-documents', false)
on conflict do nothing;

create policy "documents_upload" on storage.objects for insert
  with check (bucket_id = 'medical-documents' and auth.role() = 'authenticated');

create policy "documents_read" on storage.objects for select
  using (bucket_id = 'medical-documents' and auth.role() = 'authenticated');

create policy "documents_delete" on storage.objects for delete
  using (bucket_id = 'medical-documents' and auth.uid()::text = (storage.foldername(name))[1]);
