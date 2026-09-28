export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      activities: {
        Row: {
          activity_type: Database["public"]["Enums"]["activity_type"]
          assigned_user_id: string | null
          completed_at: string | null
          contact_id: string | null
          contract_id: string | null
          created_at: string
          description: string | null
          id: string
          opportunity_id: string | null
          organization_id: string | null
          property_id: string | null
          scheduled_at: string | null
          status: Database["public"]["Enums"]["activity_status"]
          subject: string
          workspace_id: string
        }
        Insert: {
          activity_type: Database["public"]["Enums"]["activity_type"]
          assigned_user_id?: string | null
          completed_at?: string | null
          contact_id?: string | null
          contract_id?: string | null
          created_at?: string
          description?: string | null
          id?: string
          opportunity_id?: string | null
          organization_id?: string | null
          property_id?: string | null
          scheduled_at?: string | null
          status?: Database["public"]["Enums"]["activity_status"]
          subject: string
          workspace_id: string
        }
        Update: {
          activity_type?: Database["public"]["Enums"]["activity_type"]
          assigned_user_id?: string | null
          completed_at?: string | null
          contact_id?: string | null
          contract_id?: string | null
          created_at?: string
          description?: string | null
          id?: string
          opportunity_id?: string | null
          organization_id?: string | null
          property_id?: string | null
          scheduled_at?: string | null
          status?: Database["public"]["Enums"]["activity_status"]
          subject?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "activities_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "activities_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_events: {
        Row: {
          action: string
          actor_user_id: string | null
          entity_id: string
          entity_type: string
          id: string
          new_values: Json | null
          occurred_at: string
          old_values: Json | null
          request_id: string | null
          workspace_id: string | null
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          entity_id: string
          entity_type: string
          id?: string
          new_values?: Json | null
          occurred_at?: string
          old_values?: Json | null
          request_id?: string | null
          workspace_id?: string | null
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          entity_id?: string
          entity_type?: string
          id?: string
          new_values?: Json | null
          occurred_at?: string
          old_values?: Json | null
          request_id?: string | null
          workspace_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      buildings: {
        Row: {
          building_number: string | null
          building_type: string | null
          created_at: string
          floors: number | null
          id: string
          name: string
          notes: string | null
          property_id: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          building_number?: string | null
          building_type?: string | null
          created_at?: string
          floors?: number | null
          id?: string
          name: string
          notes?: string | null
          property_id: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          building_number?: string | null
          building_type?: string | null
          created_at?: string
          floors?: number | null
          id?: string
          name?: string
          notes?: string | null
          property_id?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "buildings_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "buildings_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "buildings_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "buildings_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      canadabuys_runs: {
        Row: {
          created_at: string
          error_count: number
          error_message: string | null
          fetched_count: number
          finished_at: string | null
          id: string
          inserted_count: number
          lead_created_count: number
          qualifying_count: number
          query: string
          region: string
          started_at: string
          status: string
          updated_count: number
          workspace_id: string
        }
        Insert: {
          created_at?: string
          error_count?: number
          error_message?: string | null
          fetched_count?: number
          finished_at?: string | null
          id?: string
          inserted_count?: number
          lead_created_count?: number
          qualifying_count?: number
          query: string
          region?: string
          started_at?: string
          status?: string
          updated_count?: number
          workspace_id: string
        }
        Update: {
          created_at?: string
          error_count?: number
          error_message?: string | null
          fetched_count?: number
          finished_at?: string | null
          id?: string
          inserted_count?: number
          lead_created_count?: number
          qualifying_count?: number
          query?: string
          region?: string
          started_at?: string
          status?: string
          updated_count?: number
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "canadabuys_runs_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      communications: {
        Row: {
          body: string | null
          communication_type: Database["public"]["Enums"]["communication_type"]
          contact_id: string | null
          contract_id: string | null
          created_at: string
          created_by: string | null
          direction: Database["public"]["Enums"]["communication_direction"]
          external_message_id: string | null
          id: string
          issue_id: string | null
          occurred_at: string
          opportunity_id: string | null
          organization_id: string | null
          property_id: string | null
          subject: string | null
          workspace_id: string
        }
        Insert: {
          body?: string | null
          communication_type: Database["public"]["Enums"]["communication_type"]
          contact_id?: string | null
          contract_id?: string | null
          created_at?: string
          created_by?: string | null
          direction: Database["public"]["Enums"]["communication_direction"]
          external_message_id?: string | null
          id?: string
          issue_id?: string | null
          occurred_at: string
          opportunity_id?: string | null
          organization_id?: string | null
          property_id?: string | null
          subject?: string | null
          workspace_id: string
        }
        Update: {
          body?: string | null
          communication_type?: Database["public"]["Enums"]["communication_type"]
          contact_id?: string | null
          contract_id?: string | null
          created_at?: string
          created_by?: string | null
          direction?: Database["public"]["Enums"]["communication_direction"]
          external_message_id?: string | null
          id?: string
          issue_id?: string | null
          occurred_at?: string
          opportunity_id?: string | null
          organization_id?: string | null
          property_id?: string | null
          subject?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "communications_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_issue_id_fkey"
            columns: ["issue_id"]
            isOneToOne: false
            referencedRelation: "issues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_issue_id_fkey"
            columns: ["issue_id"]
            isOneToOne: false
            referencedRelation: "open_issue_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communications_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "communications_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      contacts: {
        Row: {
          created_at: string
          email: string | null
          first_name: string
          id: string
          job_title: string | null
          last_name: string
          linkedin_url: string | null
          mobile: string | null
          notes: string | null
          phone: string | null
          phone_extension: string | null
          source_confidence: string | null
          source_label: string | null
          source_url: string | null
          source_verified_at: string | null
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          email?: string | null
          first_name: string
          id?: string
          job_title?: string | null
          last_name: string
          linkedin_url?: string | null
          mobile?: string | null
          notes?: string | null
          phone?: string | null
          phone_extension?: string | null
          source_confidence?: string | null
          source_label?: string | null
          source_url?: string | null
          source_verified_at?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          email?: string | null
          first_name?: string
          id?: string
          job_title?: string | null
          last_name?: string
          linkedin_url?: string | null
          mobile?: string | null
          notes?: string | null
          phone?: string | null
          phone_extension?: string | null
          source_confidence?: string | null
          source_label?: string | null
          source_url?: string | null
          source_verified_at?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contacts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      contract_services: {
        Row: {
          active: boolean
          contract_id: string
          contract_price: number
          created_at: string
          end_date: string | null
          id: string
          pricing_model: Database["public"]["Enums"]["pricing_model"]
          quantity: number | null
          scope_description: string
          service_definition_id: string
          start_date: string
          unit: string | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          active?: boolean
          contract_id: string
          contract_price?: number
          created_at?: string
          end_date?: string | null
          id?: string
          pricing_model: Database["public"]["Enums"]["pricing_model"]
          quantity?: number | null
          scope_description: string
          service_definition_id: string
          start_date: string
          unit?: string | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          active?: boolean
          contract_id?: string
          contract_price?: number
          created_at?: string
          end_date?: string | null
          id?: string
          pricing_model?: Database["public"]["Enums"]["pricing_model"]
          quantity?: number | null
          scope_description?: string
          service_definition_id?: string
          start_date?: string
          unit?: string | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contract_services_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contract_services_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contract_services_service_definition_id_fkey"
            columns: ["service_definition_id"]
            isOneToOne: false
            referencedRelation: "service_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contract_services_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      contractors: {
        Row: {
          id: string
          insurance_document_id: string | null
          insurance_expiry: string | null
          notes: string | null
          organization_id: string
          status: Database["public"]["Enums"]["record_status"]
          workspace_id: string
        }
        Insert: {
          id?: string
          insurance_document_id?: string | null
          insurance_expiry?: string | null
          notes?: string | null
          organization_id: string
          status?: Database["public"]["Enums"]["record_status"]
          workspace_id: string
        }
        Update: {
          id?: string
          insurance_document_id?: string | null
          insurance_expiry?: string | null
          notes?: string | null
          organization_id?: string
          status?: Database["public"]["Enums"]["record_status"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contractors_insurance_document_id_fkey"
            columns: ["insurance_document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contractors_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contractors_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      contracts: {
        Row: {
          billing_frequency: string | null
          contract_number: string
          contract_value: number
          created_at: string
          end_date: string | null
          id: string
          name: string
          opportunity_id: string | null
          organization_id: string
          property_id: string
          proposal_id: string | null
          renewal_type: string | null
          signed_document_id: string | null
          source_estimate_id: string | null
          start_date: string
          status: Database["public"]["Enums"]["contract_status"]
          terminated_at: string | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          billing_frequency?: string | null
          contract_number: string
          contract_value?: number
          created_at?: string
          end_date?: string | null
          id?: string
          name: string
          opportunity_id?: string | null
          organization_id: string
          property_id: string
          proposal_id?: string | null
          renewal_type?: string | null
          signed_document_id?: string | null
          source_estimate_id?: string | null
          start_date: string
          status?: Database["public"]["Enums"]["contract_status"]
          terminated_at?: string | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          billing_frequency?: string | null
          contract_number?: string
          contract_value?: number
          created_at?: string
          end_date?: string | null
          id?: string
          name?: string
          opportunity_id?: string | null
          organization_id?: string
          property_id?: string
          proposal_id?: string | null
          renewal_type?: string | null
          signed_document_id?: string | null
          source_estimate_id?: string | null
          start_date?: string
          status?: Database["public"]["Enums"]["contract_status"]
          terminated_at?: string | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contracts_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "contracts_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_signed_document_id_fkey"
            columns: ["signed_document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_source_estimate_id_fkey"
            columns: ["source_estimate_id"]
            isOneToOne: false
            referencedRelation: "estimates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      crew_members: {
        Row: {
          crew_id: string
          employee_id: string
          end_date: string | null
          id: string
          start_date: string
          workspace_id: string
        }
        Insert: {
          crew_id: string
          employee_id: string
          end_date?: string | null
          id?: string
          start_date: string
          workspace_id: string
        }
        Update: {
          crew_id?: string
          employee_id?: string
          end_date?: string | null
          id?: string
          start_date?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "crew_members_crew_id_fkey"
            columns: ["crew_id"]
            isOneToOne: false
            referencedRelation: "crews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crew_members_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crew_members_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      crews: {
        Row: {
          crew_type: string | null
          id: string
          name: string
          status: Database["public"]["Enums"]["crew_status"]
          supervisor_employee_id: string | null
          workspace_id: string
        }
        Insert: {
          crew_type?: string | null
          id?: string
          name: string
          status?: Database["public"]["Enums"]["crew_status"]
          supervisor_employee_id?: string | null
          workspace_id: string
        }
        Update: {
          crew_type?: string | null
          id?: string
          name?: string
          status?: Database["public"]["Enums"]["crew_status"]
          supervisor_employee_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "crews_supervisor_employee_id_fkey"
            columns: ["supervisor_employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crews_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      documents: {
        Row: {
          created_at: string
          document_type: Database["public"]["Enums"]["document_type"]
          entity_id: string
          entity_type: string
          file_name: string
          file_size: number | null
          id: string
          mime_type: string | null
          storage_path: string
          uploaded_by: string | null
          workspace_id: string
        }
        Insert: {
          created_at?: string
          document_type?: Database["public"]["Enums"]["document_type"]
          entity_id: string
          entity_type: string
          file_name: string
          file_size?: number | null
          id?: string
          mime_type?: string | null
          storage_path: string
          uploaded_by?: string | null
          workspace_id: string
        }
        Update: {
          created_at?: string
          document_type?: Database["public"]["Enums"]["document_type"]
          entity_id?: string
          entity_type?: string
          file_name?: string
          file_size?: number | null
          id?: string
          mime_type?: string | null
          storage_path?: string
          uploaded_by?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "documents_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      employees: {
        Row: {
          cost_rate: number | null
          created_at: string
          email: string | null
          employment_status: Database["public"]["Enums"]["employment_status"]
          employment_type: Database["public"]["Enums"]["employment_type"]
          first_name: string
          hire_date: string | null
          id: string
          last_name: string
          notes: string | null
          phone: string | null
          termination_date: string | null
          updated_at: string
          user_id: string | null
          workspace_id: string
        }
        Insert: {
          cost_rate?: number | null
          created_at?: string
          email?: string | null
          employment_status?: Database["public"]["Enums"]["employment_status"]
          employment_type?: Database["public"]["Enums"]["employment_type"]
          first_name: string
          hire_date?: string | null
          id?: string
          last_name: string
          notes?: string | null
          phone?: string | null
          termination_date?: string | null
          updated_at?: string
          user_id?: string | null
          workspace_id: string
        }
        Update: {
          cost_rate?: number | null
          created_at?: string
          email?: string | null
          employment_status?: Database["public"]["Enums"]["employment_status"]
          employment_type?: Database["public"]["Enums"]["employment_type"]
          first_name?: string
          hire_date?: string | null
          id?: string
          last_name?: string
          notes?: string | null
          phone?: string | null
          termination_date?: string | null
          updated_at?: string
          user_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "employees_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      equipment: {
        Row: {
          asset_number: string
          current_location: string | null
          equipment_type: string
          id: string
          name: string
          notes: string | null
          operating_cost_rate: number | null
          purchase_cost: number | null
          purchase_date: string | null
          serial_number: string | null
          status: Database["public"]["Enums"]["equipment_status"]
          workspace_id: string
        }
        Insert: {
          asset_number: string
          current_location?: string | null
          equipment_type: string
          id?: string
          name: string
          notes?: string | null
          operating_cost_rate?: number | null
          purchase_cost?: number | null
          purchase_date?: string | null
          serial_number?: string | null
          status?: Database["public"]["Enums"]["equipment_status"]
          workspace_id: string
        }
        Update: {
          asset_number?: string
          current_location?: string | null
          equipment_type?: string
          id?: string
          name?: string
          notes?: string | null
          operating_cost_rate?: number | null
          purchase_cost?: number | null
          purchase_date?: string | null
          serial_number?: string | null
          status?: Database["public"]["Enums"]["equipment_status"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "equipment_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      estimate_items: {
        Row: {
          description: string
          estimate_id: string
          estimated_equipment_cost: number
          estimated_labor_cost: number
          estimated_material_cost: number
          estimated_subcontractor_cost: number
          id: string
          line_total: number
          quantity: number
          service_definition_id: string | null
          sort_order: number
          unit: string | null
          unit_price: number
          workspace_id: string
        }
        Insert: {
          description: string
          estimate_id: string
          estimated_equipment_cost?: number
          estimated_labor_cost?: number
          estimated_material_cost?: number
          estimated_subcontractor_cost?: number
          id?: string
          line_total?: number
          quantity?: number
          service_definition_id?: string | null
          sort_order?: number
          unit?: string | null
          unit_price?: number
          workspace_id: string
        }
        Update: {
          description?: string
          estimate_id?: string
          estimated_equipment_cost?: number
          estimated_labor_cost?: number
          estimated_material_cost?: number
          estimated_subcontractor_cost?: number
          id?: string
          line_total?: number
          quantity?: number
          service_definition_id?: string | null
          sort_order?: number
          unit?: string | null
          unit_price?: number
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "estimate_items_estimate_id_fkey"
            columns: ["estimate_id"]
            isOneToOne: false
            referencedRelation: "estimates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "estimate_items_service_definition_id_fkey"
            columns: ["service_definition_id"]
            isOneToOne: false
            referencedRelation: "service_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "estimate_items_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      estimates: {
        Row: {
          accepted_at: string | null
          created_at: string
          created_by: string | null
          estimate_kind: string
          estimate_number: string
          estimated_direct_cost: number
          estimated_gross_profit: number
          estimated_margin: number
          estimated_start_date: string | null
          id: string
          opportunity_id: string | null
          organization_id: string
          property_id: string | null
          rejected_at: string | null
          sent_at: string | null
          site_verification_notes: string | null
          site_verified_at: string | null
          site_verified_by: string | null
          status: Database["public"]["Enums"]["estimate_status"]
          subtotal: number
          tax: number
          total: number
          updated_at: string
          valid_until: string | null
          workspace_id: string
        }
        Insert: {
          accepted_at?: string | null
          created_at?: string
          created_by?: string | null
          estimate_kind?: string
          estimate_number: string
          estimated_direct_cost?: number
          estimated_gross_profit?: number
          estimated_margin?: number
          estimated_start_date?: string | null
          id?: string
          opportunity_id?: string | null
          organization_id: string
          property_id?: string | null
          rejected_at?: string | null
          sent_at?: string | null
          site_verification_notes?: string | null
          site_verified_at?: string | null
          site_verified_by?: string | null
          status?: Database["public"]["Enums"]["estimate_status"]
          subtotal?: number
          tax?: number
          total?: number
          updated_at?: string
          valid_until?: string | null
          workspace_id: string
        }
        Update: {
          accepted_at?: string | null
          created_at?: string
          created_by?: string | null
          estimate_kind?: string
          estimate_number?: string
          estimated_direct_cost?: number
          estimated_gross_profit?: number
          estimated_margin?: number
          estimated_start_date?: string | null
          id?: string
          opportunity_id?: string | null
          organization_id?: string
          property_id?: string | null
          rejected_at?: string | null
          sent_at?: string | null
          site_verification_notes?: string | null
          site_verified_at?: string | null
          site_verified_by?: string | null
          status?: Database["public"]["Enums"]["estimate_status"]
          subtotal?: number
          tax?: number
          total?: number
          updated_at?: string
          valid_until?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "estimates_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "estimates_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "estimates_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "estimates_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "estimates_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "estimates_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      expenses: {
        Row: {
          amount: number
          created_at: string
          description: string
          employee_id: string | null
          expense_date: string
          expense_type: string
          id: string
          property_id: string | null
          receipt_document_id: string | null
          status: Database["public"]["Enums"]["expense_status"]
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          description: string
          employee_id?: string | null
          expense_date: string
          expense_type: string
          id?: string
          property_id?: string | null
          receipt_document_id?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          description?: string
          employee_id?: string | null
          expense_date?: string
          expense_type?: string
          id?: string
          property_id?: string | null
          receipt_document_id?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "expenses_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "expenses_receipt_document_id_fkey"
            columns: ["receipt_document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      inbound_submissions: {
        Row: {
          channel_detail: string | null
          created_at: string
          id: string
          lead_source_id: string | null
          matched_lead_id: string | null
          message: string | null
          raw_payload: Json | null
          status: string
          submitted_email: string | null
          submitted_name: string | null
          submitted_phone: string | null
          utm_campaign: string | null
          utm_source: string | null
          wix_submission_id: string | null
          workspace_id: string
        }
        Insert: {
          channel_detail?: string | null
          created_at?: string
          id?: string
          lead_source_id?: string | null
          matched_lead_id?: string | null
          message?: string | null
          raw_payload?: Json | null
          status?: string
          submitted_email?: string | null
          submitted_name?: string | null
          submitted_phone?: string | null
          utm_campaign?: string | null
          utm_source?: string | null
          wix_submission_id?: string | null
          workspace_id: string
        }
        Update: {
          channel_detail?: string | null
          created_at?: string
          id?: string
          lead_source_id?: string | null
          matched_lead_id?: string | null
          message?: string | null
          raw_payload?: Json | null
          status?: string
          submitted_email?: string | null
          submitted_name?: string | null
          submitted_phone?: string | null
          utm_campaign?: string | null
          utm_source?: string | null
          wix_submission_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inbound_submissions_lead_source_id_fkey"
            columns: ["lead_source_id"]
            isOneToOne: false
            referencedRelation: "lead_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inbound_submissions_matched_lead_id_fkey"
            columns: ["matched_lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inbound_submissions_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      inspection_items: {
        Row: {
          criterion: string
          id: string
          inspection_id: string
          issue_id: string | null
          notes: string | null
          result: Database["public"]["Enums"]["inspection_result"]
          workspace_id: string
        }
        Insert: {
          criterion: string
          id?: string
          inspection_id: string
          issue_id?: string | null
          notes?: string | null
          result: Database["public"]["Enums"]["inspection_result"]
          workspace_id: string
        }
        Update: {
          criterion?: string
          id?: string
          inspection_id?: string
          issue_id?: string | null
          notes?: string | null
          result?: Database["public"]["Enums"]["inspection_result"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inspection_items_inspection_id_fkey"
            columns: ["inspection_id"]
            isOneToOne: false
            referencedRelation: "inspections"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspection_items_issue_id_fkey"
            columns: ["issue_id"]
            isOneToOne: false
            referencedRelation: "issues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspection_items_issue_id_fkey"
            columns: ["issue_id"]
            isOneToOne: false
            referencedRelation: "open_issue_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspection_items_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      inspections: {
        Row: {
          completed_at: string | null
          contract_id: string | null
          id: string
          inspection_type: string
          inspector_id: string | null
          notes: string | null
          overall_result:
            | Database["public"]["Enums"]["inspection_result"]
            | null
          property_id: string
          scheduled_at: string | null
          started_at: string | null
          status: Database["public"]["Enums"]["inspection_status"]
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          completed_at?: string | null
          contract_id?: string | null
          id?: string
          inspection_type: string
          inspector_id?: string | null
          notes?: string | null
          overall_result?:
            | Database["public"]["Enums"]["inspection_result"]
            | null
          property_id: string
          scheduled_at?: string | null
          started_at?: string | null
          status?: Database["public"]["Enums"]["inspection_status"]
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          completed_at?: string | null
          contract_id?: string | null
          id?: string
          inspection_type?: string
          inspector_id?: string | null
          notes?: string | null
          overall_result?:
            | Database["public"]["Enums"]["inspection_result"]
            | null
          property_id?: string
          scheduled_at?: string | null
          started_at?: string | null
          status?: Database["public"]["Enums"]["inspection_status"]
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inspections_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspections_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspections_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspections_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspections_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "inspections_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspections_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inspections_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_items: {
        Row: {
          contract_service_id: string | null
          description: string
          id: string
          invoice_id: string
          quantity: number
          total: number
          unit_price: number
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          contract_service_id?: string | null
          description: string
          id?: string
          invoice_id: string
          quantity?: number
          total?: number
          unit_price?: number
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          contract_service_id?: string | null
          description?: string
          id?: string
          invoice_id?: string
          quantity?: number
          total?: number
          unit_price?: number
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "invoice_items_contract_service_id_fkey"
            columns: ["contract_service_id"]
            isOneToOne: false
            referencedRelation: "contract_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_items_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_items_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_items_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      invoices: {
        Row: {
          contract_id: string | null
          created_at: string
          due_date: string | null
          external_accounting_id: string | null
          id: string
          invoice_date: string
          invoice_number: string
          organization_id: string
          property_id: string | null
          status: Database["public"]["Enums"]["invoice_status"]
          subtotal: number
          tax: number
          total: number
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          contract_id?: string | null
          created_at?: string
          due_date?: string | null
          external_accounting_id?: string | null
          id?: string
          invoice_date: string
          invoice_number: string
          organization_id: string
          property_id?: string | null
          status?: Database["public"]["Enums"]["invoice_status"]
          subtotal?: number
          tax?: number
          total?: number
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          contract_id?: string | null
          created_at?: string
          due_date?: string | null
          external_accounting_id?: string | null
          id?: string
          invoice_date?: string
          invoice_number?: string
          organization_id?: string
          property_id?: string | null
          status?: Database["public"]["Enums"]["invoice_status"]
          subtotal?: number
          tax?: number
          total?: number
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "invoices_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "invoices_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      issues: {
        Row: {
          assigned_to: string | null
          contract_id: string | null
          created_at: string
          customer_visible: boolean
          description: string
          due_at: string | null
          id: string
          issue_type: Database["public"]["Enums"]["issue_type"]
          property_id: string
          reported_at: string
          reported_by: string | null
          resolution_notes: string | null
          resolved_at: string | null
          severity: Database["public"]["Enums"]["issue_severity"]
          status: Database["public"]["Enums"]["issue_status"]
          title: string
          updated_at: string
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          assigned_to?: string | null
          contract_id?: string | null
          created_at?: string
          customer_visible?: boolean
          description: string
          due_at?: string | null
          id?: string
          issue_type: Database["public"]["Enums"]["issue_type"]
          property_id: string
          reported_at?: string
          reported_by?: string | null
          resolution_notes?: string | null
          resolved_at?: string | null
          severity?: Database["public"]["Enums"]["issue_severity"]
          status?: Database["public"]["Enums"]["issue_status"]
          title: string
          updated_at?: string
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          assigned_to?: string | null
          contract_id?: string | null
          created_at?: string
          customer_visible?: boolean
          description?: string
          due_at?: string | null
          id?: string
          issue_type?: Database["public"]["Enums"]["issue_type"]
          property_id?: string
          reported_at?: string
          reported_by?: string | null
          resolution_notes?: string | null
          resolved_at?: string | null
          severity?: Database["public"]["Enums"]["issue_severity"]
          status?: Database["public"]["Enums"]["issue_status"]
          title?: string
          updated_at?: string
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "issues_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "issues_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      lead_sources: {
        Row: {
          adapter: string
          cadence: string | null
          channel: Database["public"]["Enums"]["lead_channel"]
          created_at: string
          field_mapping: Json | null
          id: string
          jurisdiction_url: string | null
          last_run_at: string | null
          last_success_at: string | null
          name: string
          notes: string | null
          query_params: Json | null
          region: string | null
          status: Database["public"]["Enums"]["lead_source_status"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          adapter?: string
          cadence?: string | null
          channel: Database["public"]["Enums"]["lead_channel"]
          created_at?: string
          field_mapping?: Json | null
          id?: string
          jurisdiction_url?: string | null
          last_run_at?: string | null
          last_success_at?: string | null
          name: string
          notes?: string | null
          query_params?: Json | null
          region?: string | null
          status?: Database["public"]["Enums"]["lead_source_status"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          adapter?: string
          cadence?: string | null
          channel?: Database["public"]["Enums"]["lead_channel"]
          created_at?: string
          field_mapping?: Json | null
          id?: string
          jurisdiction_url?: string | null
          last_run_at?: string | null
          last_success_at?: string | null
          name?: string
          notes?: string | null
          query_params?: Json | null
          region?: string | null
          status?: Database["public"]["Enums"]["lead_source_status"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "lead_sources_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      leads: {
        Row: {
          contact_id: string | null
          created_at: string
          disqualified_at: string | null
          id: string
          lead_type: string | null
          organization_id: string | null
          owner_user_id: string | null
          property_id: string | null
          qualified_at: string | null
          region: string | null
          score: number | null
          source: string | null
          source_detail_id: string | null
          source_detail_table: string | null
          status: string
          workspace_id: string
        }
        Insert: {
          contact_id?: string | null
          created_at?: string
          disqualified_at?: string | null
          id?: string
          lead_type?: string | null
          organization_id?: string | null
          owner_user_id?: string | null
          property_id?: string | null
          qualified_at?: string | null
          region?: string | null
          score?: number | null
          source?: string | null
          source_detail_id?: string | null
          source_detail_table?: string | null
          status?: string
          workspace_id: string
        }
        Update: {
          contact_id?: string | null
          created_at?: string
          disqualified_at?: string | null
          id?: string
          lead_type?: string | null
          organization_id?: string | null
          owner_user_id?: string | null
          property_id?: string | null
          qualified_at?: string | null
          region?: string | null
          score?: number | null
          source?: string | null
          source_detail_id?: string | null
          source_detail_table?: string | null
          status?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "leads_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leads_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leads_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leads_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leads_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "leads_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      material_usage: {
        Row: {
          created_at: string
          id: string
          material_name: string
          property_id: string | null
          quantity: number
          total_cost: number
          unit: string
          unit_cost: number
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          material_name: string
          property_id?: string | null
          quantity: number
          total_cost: number
          unit: string
          unit_cost: number
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          created_at?: string
          id?: string
          material_name?: string
          property_id?: string | null
          quantity?: number
          total_cost?: number
          unit?: string
          unit_cost?: number
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "material_usage_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_usage_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_usage_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "material_usage_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_usage_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_usage_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      notes: {
        Row: {
          body: string
          created_at: string
          created_by: string | null
          entity_id: string
          entity_type: string
          id: string
          workspace_id: string
        }
        Insert: {
          body: string
          created_at?: string
          created_by?: string | null
          entity_id: string
          entity_type: string
          id?: string
          workspace_id: string
        }
        Update: {
          body?: string
          created_at?: string
          created_by?: string | null
          entity_id?: string
          entity_type?: string
          id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notes_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          action_href: string | null
          body: string | null
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at: string
          entity_id: string | null
          entity_type: string | null
          id: string
          read_at: string | null
          sent_at: string | null
          status: Database["public"]["Enums"]["notification_status"]
          title: string
          user_id: string
          workspace_id: string
        }
        Insert: {
          action_href?: string | null
          body?: string | null
          channel?: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          entity_id?: string | null
          entity_type?: string | null
          id?: string
          read_at?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          title: string
          user_id: string
          workspace_id: string
        }
        Update: {
          action_href?: string | null
          body?: string | null
          channel?: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          entity_id?: string | null
          entity_type?: string | null
          id?: string
          read_at?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          title?: string
          user_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      opportunities: {
        Row: {
          closed_at: string | null
          created_at: string
          estimated_close_date: string | null
          estimated_start_date: string | null
          estimated_value: number
          id: string
          lead_id: string | null
          lost_reason: string | null
          lost_reason_category:
            | Database["public"]["Enums"]["opportunity_lost_reason_category"]
            | null
          name: string
          notes: string | null
          organization_id: string
          owner_user_id: string | null
          probability: number | null
          property_id: string | null
          stage: Database["public"]["Enums"]["opportunity_stage"]
          status: Database["public"]["Enums"]["opportunity_status"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          closed_at?: string | null
          created_at?: string
          estimated_close_date?: string | null
          estimated_start_date?: string | null
          estimated_value?: number
          id?: string
          lead_id?: string | null
          lost_reason?: string | null
          lost_reason_category?:
            | Database["public"]["Enums"]["opportunity_lost_reason_category"]
            | null
          name: string
          notes?: string | null
          organization_id: string
          owner_user_id?: string | null
          probability?: number | null
          property_id?: string | null
          stage?: Database["public"]["Enums"]["opportunity_stage"]
          status?: Database["public"]["Enums"]["opportunity_status"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          closed_at?: string | null
          created_at?: string
          estimated_close_date?: string | null
          estimated_start_date?: string | null
          estimated_value?: number
          id?: string
          lead_id?: string | null
          lost_reason?: string | null
          lost_reason_category?:
            | Database["public"]["Enums"]["opportunity_lost_reason_category"]
            | null
          name?: string
          notes?: string | null
          organization_id?: string
          owner_user_id?: string | null
          probability?: number | null
          property_id?: string | null
          stage?: Database["public"]["Enums"]["opportunity_stage"]
          status?: Database["public"]["Enums"]["opportunity_status"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "opportunities_lead_id_fkey"
            columns: ["lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "opportunities_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      opportunity_stage_history: {
        Row: {
          changed_at: string
          changed_by: string | null
          from_stage: Database["public"]["Enums"]["opportunity_stage"] | null
          id: string
          opportunity_id: string
          to_stage: Database["public"]["Enums"]["opportunity_stage"]
          workspace_id: string
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          from_stage?: Database["public"]["Enums"]["opportunity_stage"] | null
          id?: string
          opportunity_id: string
          to_stage: Database["public"]["Enums"]["opportunity_stage"]
          workspace_id: string
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          from_stage?: Database["public"]["Enums"]["opportunity_stage"] | null
          id?: string
          opportunity_id?: string
          to_stage?: Database["public"]["Enums"]["opportunity_stage"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "opportunity_stage_history_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunity_stage_history_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_contacts: {
        Row: {
          contact_id: string
          end_date: string | null
          id: string
          is_primary: boolean
          organization_id: string
          relationship_type: string
          start_date: string | null
          workspace_id: string
        }
        Insert: {
          contact_id: string
          end_date?: string | null
          id?: string
          is_primary?: boolean
          organization_id: string
          relationship_type: string
          start_date?: string | null
          workspace_id: string
        }
        Update: {
          contact_id?: string
          end_date?: string | null
          id?: string
          is_primary?: boolean
          organization_id?: string
          relationship_type?: string
          start_date?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_contacts_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_contacts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_contacts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          archived_at: string | null
          buildings_managed: number | null
          created_at: string
          doors_managed: number | null
          email: string | null
          hq_address_line_1: string | null
          hq_address_line_2: string | null
          hq_city: string | null
          hq_postal_code: string | null
          hq_province: string | null
          id: string
          legal_name: string
          linkedin_url: string | null
          main_fax: string | null
          notes: string | null
          operating_name: string | null
          organization_type: Database["public"]["Enums"]["organization_type"]
          phone: string | null
          primary_region: string | null
          service_regions: string[] | null
          source_notes: string | null
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          website: string | null
          workspace_id: string
        }
        Insert: {
          archived_at?: string | null
          buildings_managed?: number | null
          created_at?: string
          doors_managed?: number | null
          email?: string | null
          hq_address_line_1?: string | null
          hq_address_line_2?: string | null
          hq_city?: string | null
          hq_postal_code?: string | null
          hq_province?: string | null
          id?: string
          legal_name: string
          linkedin_url?: string | null
          main_fax?: string | null
          notes?: string | null
          operating_name?: string | null
          organization_type: Database["public"]["Enums"]["organization_type"]
          phone?: string | null
          primary_region?: string | null
          service_regions?: string[] | null
          source_notes?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          website?: string | null
          workspace_id: string
        }
        Update: {
          archived_at?: string | null
          buildings_managed?: number | null
          created_at?: string
          doors_managed?: number | null
          email?: string | null
          hq_address_line_1?: string | null
          hq_address_line_2?: string | null
          hq_city?: string | null
          hq_postal_code?: string | null
          hq_province?: string | null
          id?: string
          legal_name?: string
          linkedin_url?: string | null
          main_fax?: string | null
          notes?: string | null
          operating_name?: string | null
          organization_type?: Database["public"]["Enums"]["organization_type"]
          phone?: string | null
          primary_region?: string | null
          service_regions?: string[] | null
          source_notes?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          website?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organizations_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_drafts: {
        Row: {
          approved_at: string | null
          body: string
          channel: string
          contact_id: string | null
          created_at: string
          created_by: string | null
          evidence: Json
          generated_at: string
          id: string
          objective: string
          outreach_target_id: string
          property_id: string | null
          provider: string | null
          provider_message_id: string | null
          provider_thread_id: string | null
          sent_at: string | null
          state: string
          subject: string | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          approved_at?: string | null
          body: string
          channel?: string
          contact_id?: string | null
          created_at?: string
          created_by?: string | null
          evidence?: Json
          generated_at?: string
          id?: string
          objective?: string
          outreach_target_id: string
          property_id?: string | null
          provider?: string | null
          provider_message_id?: string | null
          provider_thread_id?: string | null
          sent_at?: string | null
          state?: string
          subject?: string | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          approved_at?: string | null
          body?: string
          channel?: string
          contact_id?: string | null
          created_at?: string
          created_by?: string | null
          evidence?: Json
          generated_at?: string
          id?: string
          objective?: string
          outreach_target_id?: string
          property_id?: string | null
          provider?: string | null
          provider_message_id?: string | null
          provider_thread_id?: string | null
          sent_at?: string | null
          state?: string
          subject?: string | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_drafts_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_drafts_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "outreach_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_drafts_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_drafts_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_target_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_drafts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_drafts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_drafts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "outreach_drafts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_enrollments: {
        Row: {
          completed_at: string | null
          created_at: string
          current_step_order: number
          enrolled_by: string | null
          id: string
          next_run_at: string
          outreach_target_id: string
          sequence_id: string
          status: Database["public"]["Enums"]["enrollment_status"]
          workspace_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          current_step_order?: number
          enrolled_by?: string | null
          id?: string
          next_run_at?: string
          outreach_target_id: string
          sequence_id: string
          status?: Database["public"]["Enums"]["enrollment_status"]
          workspace_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          current_step_order?: number
          enrolled_by?: string | null
          id?: string
          next_run_at?: string
          outreach_target_id?: string
          sequence_id?: string
          status?: Database["public"]["Enums"]["enrollment_status"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_enrollments_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "outreach_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_enrollments_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_enrollments_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_target_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_enrollments_sequence_id_fkey"
            columns: ["sequence_id"]
            isOneToOne: false
            referencedRelation: "outreach_sequences"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_enrollments_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_lists: {
        Row: {
          created_at: string
          created_by: string | null
          criteria: Json | null
          id: string
          name: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          criteria?: Json | null
          id?: string
          name: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          criteria?: Json | null
          id?: string
          name?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_lists_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_replies: {
        Row: {
          classification: string
          created_at: string
          id: string
          outreach_draft_id: string | null
          outreach_target_id: string
          provider: string | null
          provider_message_id: string | null
          provider_thread_id: string | null
          raw_metadata: Json
          received_at: string
          referred_contact: string | null
          renewal_date: string | null
          summary: string | null
          workspace_id: string
        }
        Insert: {
          classification: string
          created_at?: string
          id?: string
          outreach_draft_id?: string | null
          outreach_target_id: string
          provider?: string | null
          provider_message_id?: string | null
          provider_thread_id?: string | null
          raw_metadata?: Json
          received_at?: string
          referred_contact?: string | null
          renewal_date?: string | null
          summary?: string | null
          workspace_id: string
        }
        Update: {
          classification?: string
          created_at?: string
          id?: string
          outreach_draft_id?: string | null
          outreach_target_id?: string
          provider?: string | null
          provider_message_id?: string | null
          provider_thread_id?: string | null
          raw_metadata?: Json
          received_at?: string
          referred_contact?: string | null
          renewal_date?: string | null
          summary?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_replies_outreach_draft_id_fkey"
            columns: ["outreach_draft_id"]
            isOneToOne: false
            referencedRelation: "outreach_drafts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_replies_outreach_draft_id_fkey"
            columns: ["outreach_draft_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["latest_draft_id"]
          },
          {
            foreignKeyName: "outreach_replies_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "outreach_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_replies_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_replies_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_target_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_replies_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_sequence_steps: {
        Row: {
          body_template: string | null
          channel: Database["public"]["Enums"]["sequence_step_channel"]
          created_at: string
          delay_days: number
          id: string
          sequence_id: string
          step_order: number
          title: string
          workspace_id: string
        }
        Insert: {
          body_template?: string | null
          channel: Database["public"]["Enums"]["sequence_step_channel"]
          created_at?: string
          delay_days?: number
          id?: string
          sequence_id: string
          step_order: number
          title: string
          workspace_id: string
        }
        Update: {
          body_template?: string | null
          channel?: Database["public"]["Enums"]["sequence_step_channel"]
          created_at?: string
          delay_days?: number
          id?: string
          sequence_id?: string
          step_order?: number
          title?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_sequence_steps_sequence_id_fkey"
            columns: ["sequence_id"]
            isOneToOne: false
            referencedRelation: "outreach_sequences"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_sequence_steps_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_sequences: {
        Row: {
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_sequences_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_target_properties: {
        Row: {
          created_at: string
          id: string
          is_primary: boolean
          notes: string | null
          outreach_target_id: string
          property_id: string
          relationship_type: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_primary?: boolean
          notes?: string | null
          outreach_target_id: string
          property_id: string
          relationship_type?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_primary?: boolean
          notes?: string | null
          outreach_target_id?: string
          property_id?: string
          relationship_type?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_target_properties_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "outreach_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_target_properties_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_target_properties_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_target_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_target_properties_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_target_properties_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_target_properties_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "outreach_target_properties_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_targets: {
        Row: {
          company_address: string | null
          company_email: string | null
          company_phone: string | null
          company_website: string | null
          contact_id: string | null
          contact_name: string | null
          converted_lead_id: string | null
          created_at: string
          email: string | null
          id: string
          last_touch_at: string | null
          next_action: string | null
          next_action_due_at: string | null
          notes: string | null
          organization_id: string | null
          organization_name: string | null
          outreach_list_id: string
          owner_user_id: string | null
          phone: string | null
          priority: Database["public"]["Enums"]["work_priority"]
          property_address: string | null
          region: string | null
          score: number | null
          score_reason: string | null
          status: Database["public"]["Enums"]["outreach_target_status"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          company_address?: string | null
          company_email?: string | null
          company_phone?: string | null
          company_website?: string | null
          contact_id?: string | null
          contact_name?: string | null
          converted_lead_id?: string | null
          created_at?: string
          email?: string | null
          id?: string
          last_touch_at?: string | null
          next_action?: string | null
          next_action_due_at?: string | null
          notes?: string | null
          organization_id?: string | null
          organization_name?: string | null
          outreach_list_id: string
          owner_user_id?: string | null
          phone?: string | null
          priority?: Database["public"]["Enums"]["work_priority"]
          property_address?: string | null
          region?: string | null
          score?: number | null
          score_reason?: string | null
          status?: Database["public"]["Enums"]["outreach_target_status"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          company_address?: string | null
          company_email?: string | null
          company_phone?: string | null
          company_website?: string | null
          contact_id?: string | null
          contact_name?: string | null
          converted_lead_id?: string | null
          created_at?: string
          email?: string | null
          id?: string
          last_touch_at?: string | null
          next_action?: string | null
          next_action_due_at?: string | null
          notes?: string | null
          organization_id?: string | null
          organization_name?: string | null
          outreach_list_id?: string
          owner_user_id?: string | null
          phone?: string | null
          priority?: Database["public"]["Enums"]["work_priority"]
          property_address?: string | null
          region?: string | null
          score?: number | null
          score_reason?: string | null
          status?: Database["public"]["Enums"]["outreach_target_status"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_targets_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_converted_lead_id_fkey"
            columns: ["converted_lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_outreach_list_id_fkey"
            columns: ["outreach_list_id"]
            isOneToOne: false
            referencedRelation: "outreach_lists"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      outreach_touches: {
        Row: {
          channel: Database["public"]["Enums"]["outreach_touch_channel"]
          id: string
          notes: string | null
          occurred_at: string
          outcome: string | null
          outreach_target_id: string
          performed_by: string | null
          workspace_id: string
        }
        Insert: {
          channel: Database["public"]["Enums"]["outreach_touch_channel"]
          id?: string
          notes?: string | null
          occurred_at?: string
          outcome?: string | null
          outreach_target_id: string
          performed_by?: string | null
          workspace_id: string
        }
        Update: {
          channel?: Database["public"]["Enums"]["outreach_touch_channel"]
          id?: string
          notes?: string | null
          occurred_at?: string
          outcome?: string | null
          outreach_target_id?: string
          performed_by?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outreach_touches_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "outreach_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_touches_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_touches_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_target_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_touches_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number
          created_at: string
          external_reference: string | null
          id: string
          invoice_id: string
          payment_date: string
          payment_method: string | null
          workspace_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          external_reference?: string | null
          id?: string
          invoice_id: string
          payment_date: string
          payment_method?: string | null
          workspace_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          external_reference?: string | null
          id?: string
          invoice_id?: string
          payment_date?: string
          payment_method?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      permit_records: {
        Row: {
          applicant_name: string | null
          contractor_of_record: string | null
          created_at: string
          estimated_value: number | null
          filed_date: string | null
          id: string
          jurisdiction: string
          lead_id: string | null
          lead_source_id: string | null
          matched_organization_id: string | null
          matched_property_id: string | null
          permit_number: string | null
          permit_status: string | null
          permit_type: string | null
          property_address: string | null
          raw_payload: Json | null
          work_description: string | null
          workspace_id: string
        }
        Insert: {
          applicant_name?: string | null
          contractor_of_record?: string | null
          created_at?: string
          estimated_value?: number | null
          filed_date?: string | null
          id?: string
          jurisdiction: string
          lead_id?: string | null
          lead_source_id?: string | null
          matched_organization_id?: string | null
          matched_property_id?: string | null
          permit_number?: string | null
          permit_status?: string | null
          permit_type?: string | null
          property_address?: string | null
          raw_payload?: Json | null
          work_description?: string | null
          workspace_id: string
        }
        Update: {
          applicant_name?: string | null
          contractor_of_record?: string | null
          created_at?: string
          estimated_value?: number | null
          filed_date?: string | null
          id?: string
          jurisdiction?: string
          lead_id?: string | null
          lead_source_id?: string | null
          matched_organization_id?: string | null
          matched_property_id?: string | null
          permit_number?: string | null
          permit_status?: string | null
          permit_type?: string | null
          property_address?: string | null
          raw_payload?: Json | null
          work_description?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "permit_records_lead_id_fkey"
            columns: ["lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "permit_records_lead_source_id_fkey"
            columns: ["lead_source_id"]
            isOneToOne: false
            referencedRelation: "lead_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "permit_records_matched_organization_id_fkey"
            columns: ["matched_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "permit_records_matched_property_id_fkey"
            columns: ["matched_property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "permit_records_matched_property_id_fkey"
            columns: ["matched_property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "permit_records_matched_property_id_fkey"
            columns: ["matched_property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "permit_records_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      photos: {
        Row: {
          captured_at: string | null
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          latitude: number | null
          longitude: number | null
          photo_type: string
          storage_path: string
          uploaded_by: string | null
          workspace_id: string
        }
        Insert: {
          captured_at?: string | null
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          photo_type?: string
          storage_path: string
          uploaded_by?: string | null
          workspace_id: string
        }
        Update: {
          captured_at?: string | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          photo_type?: string
          storage_path?: string
          uploaded_by?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "photos_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      properties: {
        Row: {
          access_notes: string | null
          address_line_1: string
          address_line_2: string | null
          archived_at: string | null
          city: string
          country: string
          created_at: string
          id: string
          latitude: number | null
          longitude: number | null
          management_organization_id: string | null
          name: string
          owner_organization_id: string | null
          postal_code: string | null
          primary_customer_organization_id: string | null
          property_type: string
          province: string | null
          site_notes: string | null
          status: Database["public"]["Enums"]["property_status"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          access_notes?: string | null
          address_line_1: string
          address_line_2?: string | null
          archived_at?: string | null
          city: string
          country?: string
          created_at?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          management_organization_id?: string | null
          name: string
          owner_organization_id?: string | null
          postal_code?: string | null
          primary_customer_organization_id?: string | null
          property_type: string
          province?: string | null
          site_notes?: string | null
          status?: Database["public"]["Enums"]["property_status"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          access_notes?: string | null
          address_line_1?: string
          address_line_2?: string | null
          archived_at?: string | null
          city?: string
          country?: string
          created_at?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          management_organization_id?: string | null
          name?: string
          owner_organization_id?: string | null
          postal_code?: string | null
          primary_customer_organization_id?: string | null
          property_type?: string
          province?: string | null
          site_notes?: string | null
          status?: Database["public"]["Enums"]["property_status"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "properties_management_organization_id_fkey"
            columns: ["management_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "properties_owner_organization_id_fkey"
            columns: ["owner_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "properties_primary_customer_organization_id_fkey"
            columns: ["primary_customer_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "properties_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      property_contacts: {
        Row: {
          contact_id: string
          emergency_contact: boolean
          id: string
          is_primary: boolean
          notes: string | null
          property_id: string
          relationship_type: string
          workspace_id: string
        }
        Insert: {
          contact_id: string
          emergency_contact?: boolean
          id?: string
          is_primary?: boolean
          notes?: string | null
          property_id: string
          relationship_type: string
          workspace_id: string
        }
        Update: {
          contact_id?: string
          emergency_contact?: boolean
          id?: string
          is_primary?: boolean
          notes?: string | null
          property_id?: string
          relationship_type?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "property_contacts_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "property_contacts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "property_contacts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "property_contacts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "property_contacts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      property_intelligence: {
        Row: {
          access_complexity: string | null
          building_count: number | null
          capital_projects_signal: string | null
          construction_year: number | null
          created_at: string
          data_confidence: string | null
          estimated_sqft: number | null
          exterior_scope: string | null
          floor_count: number | null
          grounds_scope: string | null
          id: string
          intelligence_score: number | null
          intelligence_summary: string | null
          janitorial_scope: string | null
          liability_signal: string | null
          lot_area_sqft: number | null
          occupancy_signal: string | null
          ownership_type: string | null
          parking_spaces: number | null
          primary_source_label: string | null
          primary_source_url: string | null
          procurement_signal: string | null
          property_class: string | null
          property_id: string
          seasonal_priority: string | null
          snow_scope: string | null
          unit_count: number | null
          updated_at: string
          vendor_signal: string | null
          verified_at: string | null
          workspace_id: string
        }
        Insert: {
          access_complexity?: string | null
          building_count?: number | null
          capital_projects_signal?: string | null
          construction_year?: number | null
          created_at?: string
          data_confidence?: string | null
          estimated_sqft?: number | null
          exterior_scope?: string | null
          floor_count?: number | null
          grounds_scope?: string | null
          id?: string
          intelligence_score?: number | null
          intelligence_summary?: string | null
          janitorial_scope?: string | null
          liability_signal?: string | null
          lot_area_sqft?: number | null
          occupancy_signal?: string | null
          ownership_type?: string | null
          parking_spaces?: number | null
          primary_source_label?: string | null
          primary_source_url?: string | null
          procurement_signal?: string | null
          property_class?: string | null
          property_id: string
          seasonal_priority?: string | null
          snow_scope?: string | null
          unit_count?: number | null
          updated_at?: string
          vendor_signal?: string | null
          verified_at?: string | null
          workspace_id: string
        }
        Update: {
          access_complexity?: string | null
          building_count?: number | null
          capital_projects_signal?: string | null
          construction_year?: number | null
          created_at?: string
          data_confidence?: string | null
          estimated_sqft?: number | null
          exterior_scope?: string | null
          floor_count?: number | null
          grounds_scope?: string | null
          id?: string
          intelligence_score?: number | null
          intelligence_summary?: string | null
          janitorial_scope?: string | null
          liability_signal?: string | null
          lot_area_sqft?: number | null
          occupancy_signal?: string | null
          ownership_type?: string | null
          parking_spaces?: number | null
          primary_source_label?: string | null
          primary_source_url?: string | null
          procurement_signal?: string | null
          property_class?: string | null
          property_id?: string
          seasonal_priority?: string | null
          snow_scope?: string | null
          unit_count?: number | null
          updated_at?: string
          vendor_signal?: string | null
          verified_at?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "property_intelligence_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: true
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "property_intelligence_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: true
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "property_intelligence_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: true
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "property_intelligence_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      property_intelligence_sources: {
        Row: {
          confidence: string | null
          created_at: string
          id: string
          observed_at: string
          property_id: string
          published_at: string | null
          raw_payload: Json | null
          source_title: string | null
          source_type: string
          source_url: string | null
          summary: string | null
          workspace_id: string
        }
        Insert: {
          confidence?: string | null
          created_at?: string
          id?: string
          observed_at?: string
          property_id: string
          published_at?: string | null
          raw_payload?: Json | null
          source_title?: string | null
          source_type: string
          source_url?: string | null
          summary?: string | null
          workspace_id: string
        }
        Update: {
          confidence?: string | null
          created_at?: string
          id?: string
          observed_at?: string
          property_id?: string
          published_at?: string | null
          raw_payload?: Json | null
          source_title?: string | null
          source_type?: string
          source_url?: string | null
          summary?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "property_intelligence_sources_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "property_intelligence_sources_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "property_intelligence_sources_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "property_intelligence_sources_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      proposals: {
        Row: {
          accepted_at: string | null
          created_at: string
          document_id: string | null
          estimate_id: string
          id: string
          rejected_at: string | null
          sent_at: string | null
          status: Database["public"]["Enums"]["proposal_status"]
          version: number
          workspace_id: string
        }
        Insert: {
          accepted_at?: string | null
          created_at?: string
          document_id?: string | null
          estimate_id: string
          id?: string
          rejected_at?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["proposal_status"]
          version: number
          workspace_id: string
        }
        Update: {
          accepted_at?: string | null
          created_at?: string
          document_id?: string | null
          estimate_id?: string
          id?: string
          rejected_at?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["proposal_status"]
          version?: number
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "proposals_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "proposals_estimate_id_fkey"
            columns: ["estimate_id"]
            isOneToOne: false
            referencedRelation: "estimates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "proposals_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      referral_events: {
        Row: {
          created_at: string
          id: string
          lead_id: string
          referred_by_contact_id: string | null
          referred_by_organization_id: string | null
          relationship_note: string | null
          reward_status: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          lead_id: string
          referred_by_contact_id?: string | null
          referred_by_organization_id?: string | null
          relationship_note?: string | null
          reward_status?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          id?: string
          lead_id?: string
          referred_by_contact_id?: string | null
          referred_by_organization_id?: string | null
          relationship_note?: string | null
          reward_status?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "referral_events_lead_id_fkey"
            columns: ["lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_events_referred_by_contact_id_fkey"
            columns: ["referred_by_contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_events_referred_by_organization_id_fkey"
            columns: ["referred_by_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_events_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_targets: {
        Row: {
          created_at: string
          id: string
          period_end: string
          period_start: string
          target_amount: number
          target_type: string
          updated_at: string
          user_id: string | null
          workspace_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          period_end: string
          period_start: string
          target_amount?: number
          target_type?: string
          updated_at?: string
          user_id?: string | null
          workspace_id: string
        }
        Update: {
          created_at?: string
          id?: string
          period_end?: string
          period_start?: string
          target_amount?: number
          target_type?: string
          updated_at?: string
          user_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sales_targets_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      service_definitions: {
        Row: {
          active: boolean
          category: string
          created_at: string
          default_duration_minutes: number | null
          description: string | null
          id: string
          name: string
          unit_type: Database["public"]["Enums"]["unit_type"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          active?: boolean
          category: string
          created_at?: string
          default_duration_minutes?: number | null
          description?: string | null
          id?: string
          name: string
          unit_type?: Database["public"]["Enums"]["unit_type"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          active?: boolean
          category?: string
          created_at?: string
          default_duration_minutes?: number | null
          description?: string | null
          id?: string
          name?: string
          unit_type?: Database["public"]["Enums"]["unit_type"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_definitions_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      service_schedules: {
        Row: {
          active: boolean
          contract_service_id: string
          created_at: string
          day_of_month: number | null
          day_of_week: number | null
          duration_minutes: number | null
          frequency: string | null
          id: string
          instructions: string | null
          schedule_type: Database["public"]["Enums"]["schedule_type"]
          season_end: string | null
          season_start: string | null
          start_time: string | null
          updated_at: string
          weather_trigger: boolean
          workspace_id: string
        }
        Insert: {
          active?: boolean
          contract_service_id: string
          created_at?: string
          day_of_month?: number | null
          day_of_week?: number | null
          duration_minutes?: number | null
          frequency?: string | null
          id?: string
          instructions?: string | null
          schedule_type: Database["public"]["Enums"]["schedule_type"]
          season_end?: string | null
          season_start?: string | null
          start_time?: string | null
          updated_at?: string
          weather_trigger?: boolean
          workspace_id: string
        }
        Update: {
          active?: boolean
          contract_service_id?: string
          created_at?: string
          day_of_month?: number | null
          day_of_week?: number | null
          duration_minutes?: number | null
          frequency?: string | null
          id?: string
          instructions?: string | null
          schedule_type?: Database["public"]["Enums"]["schedule_type"]
          season_end?: string | null
          season_start?: string | null
          start_time?: string | null
          updated_at?: string
          weather_trigger?: boolean
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_schedules_contract_service_id_fkey"
            columns: ["contract_service_id"]
            isOneToOne: false
            referencedRelation: "contract_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_schedules_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      subcontractor_costs: {
        Row: {
          contractor_id: string
          cost: number
          created_at: string
          description: string
          id: string
          invoice_reference: string | null
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          contractor_id: string
          cost: number
          created_at?: string
          description: string
          id?: string
          invoice_reference?: string | null
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          contractor_id?: string
          cost?: number
          created_at?: string
          description?: string
          id?: string
          invoice_reference?: string | null
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subcontractor_costs_contractor_id_fkey"
            columns: ["contractor_id"]
            isOneToOne: false
            referencedRelation: "contractors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subcontractor_costs_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subcontractor_costs_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subcontractor_costs_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_registrations: {
        Row: {
          account_reference: string | null
          created_at: string
          evidence_url: string | null
          expires_on: string | null
          id: string
          notes: string | null
          registration_name: string
          source_key: string
          status: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          account_reference?: string | null
          created_at?: string
          evidence_url?: string | null
          expires_on?: string | null
          id?: string
          notes?: string | null
          registration_name: string
          source_key: string
          status?: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          account_reference?: string | null
          created_at?: string
          evidence_url?: string | null
          expires_on?: string | null
          id?: string
          notes?: string | null
          registration_name?: string
          source_key?: string
          status?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_registrations_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      system_events: {
        Row: {
          attempt_count: number
          entity_id: string
          entity_type: string
          event_type: string
          id: string
          last_error: string | null
          occurred_at: string
          payload: Json
          processed_at: string | null
          status: Database["public"]["Enums"]["system_event_status"]
          workspace_id: string | null
        }
        Insert: {
          attempt_count?: number
          entity_id: string
          entity_type: string
          event_type: string
          id?: string
          last_error?: string | null
          occurred_at?: string
          payload?: Json
          processed_at?: string | null
          status?: Database["public"]["Enums"]["system_event_status"]
          workspace_id?: string | null
        }
        Update: {
          attempt_count?: number
          entity_id?: string
          entity_type?: string
          event_type?: string
          id?: string
          last_error?: string | null
          occurred_at?: string
          payload?: Json
          processed_at?: string | null
          status?: Database["public"]["Enums"]["system_event_status"]
          workspace_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "system_events_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      target_opportunity_signals: {
        Row: {
          buyer_contact_email: string | null
          buyer_contact_name: string | null
          created_at: string
          deadline_at: string | null
          id: string
          notes: string | null
          organization_id: string | null
          property_id: string | null
          published_at: string | null
          reference_number: string | null
          service_fit: string[]
          signal_type: string
          source_confidence: string
          source_label: string | null
          source_url: string
          status: string
          target_id: string | null
          title: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          buyer_contact_email?: string | null
          buyer_contact_name?: string | null
          created_at?: string
          deadline_at?: string | null
          id?: string
          notes?: string | null
          organization_id?: string | null
          property_id?: string | null
          published_at?: string | null
          reference_number?: string | null
          service_fit?: string[]
          signal_type: string
          source_confidence?: string
          source_label?: string | null
          source_url: string
          status?: string
          target_id?: string | null
          title: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          buyer_contact_email?: string | null
          buyer_contact_name?: string | null
          created_at?: string
          deadline_at?: string | null
          id?: string
          notes?: string | null
          organization_id?: string | null
          property_id?: string | null
          published_at?: string | null
          reference_number?: string | null
          service_fit?: string[]
          signal_type?: string
          source_confidence?: string
          source_label?: string | null
          source_url?: string
          status?: string
          target_id?: string | null
          title?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "target_opportunity_signals_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "target_opportunity_signals_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "target_opportunity_signals_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "target_opportunity_signals_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "target_opportunity_signals_target_id_fkey"
            columns: ["target_id"]
            isOneToOne: false
            referencedRelation: "outreach_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "target_opportunity_signals_target_id_fkey"
            columns: ["target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "target_opportunity_signals_target_id_fkey"
            columns: ["target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_target_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "target_opportunity_signals_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          assigned_to: string | null
          completed_at: string | null
          contract_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          due_at: string | null
          id: string
          issue_id: string | null
          opportunity_id: string | null
          organization_id: string | null
          outreach_target_id: string | null
          priority: Database["public"]["Enums"]["work_priority"]
          property_id: string | null
          status: Database["public"]["Enums"]["task_status"]
          task_type: Database["public"]["Enums"]["task_type"]
          title: string
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          assigned_to?: string | null
          completed_at?: string | null
          contract_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_at?: string | null
          id?: string
          issue_id?: string | null
          opportunity_id?: string | null
          organization_id?: string | null
          outreach_target_id?: string | null
          priority?: Database["public"]["Enums"]["work_priority"]
          property_id?: string | null
          status?: Database["public"]["Enums"]["task_status"]
          task_type?: Database["public"]["Enums"]["task_type"]
          title: string
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          assigned_to?: string | null
          completed_at?: string | null
          contract_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_at?: string | null
          id?: string
          issue_id?: string | null
          opportunity_id?: string | null
          organization_id?: string | null
          outreach_target_id?: string | null
          priority?: Database["public"]["Enums"]["work_priority"]
          property_id?: string | null
          status?: Database["public"]["Enums"]["task_status"]
          task_type?: Database["public"]["Enums"]["task_type"]
          title?: string
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tasks_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_issue_id_fkey"
            columns: ["issue_id"]
            isOneToOne: false
            referencedRelation: "issues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_issue_id_fkey"
            columns: ["issue_id"]
            isOneToOne: false
            referencedRelation: "open_issue_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "outreach_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_execution_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_outreach_target_id_fkey"
            columns: ["outreach_target_id"]
            isOneToOne: false
            referencedRelation: "v_outreach_target_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "tasks_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tender_deadlines: {
        Row: {
          created_at: string
          deadline_type: string
          due_at: string
          id: string
          mandatory: boolean
          notes: string | null
          status: string
          tender_record_id: string
          title: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          deadline_type?: string
          due_at: string
          id?: string
          mandatory?: boolean
          notes?: string | null
          status?: string
          tender_record_id: string
          title: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          deadline_type?: string
          due_at?: string
          id?: string
          mandatory?: boolean
          notes?: string | null
          status?: string
          tender_record_id?: string
          title?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tender_deadlines_tender_record_id_fkey"
            columns: ["tender_record_id"]
            isOneToOne: false
            referencedRelation: "tender_records"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_deadlines_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tender_documents: {
        Row: {
          created_at: string
          document_type: string
          id: string
          is_current: boolean
          published_at: string | null
          source_url: string | null
          storage_path: string | null
          tender_record_id: string
          title: string
          version: string | null
          workspace_id: string
        }
        Insert: {
          created_at?: string
          document_type?: string
          id?: string
          is_current?: boolean
          published_at?: string | null
          source_url?: string | null
          storage_path?: string | null
          tender_record_id: string
          title: string
          version?: string | null
          workspace_id: string
        }
        Update: {
          created_at?: string
          document_type?: string
          id?: string
          is_current?: boolean
          published_at?: string | null
          source_url?: string | null
          storage_path?: string | null
          tender_record_id?: string
          title?: string
          version?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tender_documents_tender_record_id_fkey"
            columns: ["tender_record_id"]
            isOneToOne: false
            referencedRelation: "tender_records"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_documents_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tender_properties: {
        Row: {
          created_at: string
          evidence_label: string | null
          evidence_url: string | null
          id: string
          property_id: string
          scope_note: string | null
          source_confidence: string | null
          tender_record_id: string
          verified_at: string | null
          workspace_id: string
        }
        Insert: {
          created_at?: string
          evidence_label?: string | null
          evidence_url?: string | null
          id?: string
          property_id: string
          scope_note?: string | null
          source_confidence?: string | null
          tender_record_id: string
          verified_at?: string | null
          workspace_id: string
        }
        Update: {
          created_at?: string
          evidence_label?: string | null
          evidence_url?: string | null
          id?: string
          property_id?: string
          scope_note?: string | null
          source_confidence?: string | null
          tender_record_id?: string
          verified_at?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tender_properties_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_properties_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_properties_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "tender_properties_tender_record_id_fkey"
            columns: ["tender_record_id"]
            isOneToOne: false
            referencedRelation: "tender_records"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_properties_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tender_records: {
        Row: {
          action_state: string
          addenda_count: number
          bid_decision_at: string | null
          bid_decision_by: string | null
          buyer_name: string | null
          category: string | null
          closing_date: string | null
          contract_end_date: string | null
          contract_start_date: string | null
          created_at: string
          currency: string
          estimate_id: string | null
          estimated_value: number | null
          expected_rebid_date: string | null
          external_id: string
          fit_breakdown: Json
          fit_note: string | null
          fit_score: number | null
          id: string
          incumbent_name: string | null
          last_addenda_checked_at: string | null
          last_verified_at: string | null
          lead_id: string | null
          lead_source_id: string | null
          matched_organization_id: string | null
          next_action: string | null
          next_action_due_at: string | null
          no_bid_reason: string | null
          notes: string | null
          opportunity_id: string | null
          owner_user_id: string | null
          previous_award_value: number | null
          published_date: string | null
          raw_payload: Json | null
          region: string | null
          registration_required: boolean
          response_mode: string | null
          source: string
          source_url: string | null
          status: Database["public"]["Enums"]["tender_record_status"]
          submission_confirmed_at: string | null
          submission_method: string | null
          submission_receipt_url: string | null
          submission_reference: string | null
          title: string
          updated_at: string
          vendor_prerequisite_status: string | null
          watch_query: string | null
          workspace_id: string
        }
        Insert: {
          action_state?: string
          addenda_count?: number
          bid_decision_at?: string | null
          bid_decision_by?: string | null
          buyer_name?: string | null
          category?: string | null
          closing_date?: string | null
          contract_end_date?: string | null
          contract_start_date?: string | null
          created_at?: string
          currency?: string
          estimate_id?: string | null
          estimated_value?: number | null
          expected_rebid_date?: string | null
          external_id: string
          fit_breakdown?: Json
          fit_note?: string | null
          fit_score?: number | null
          id?: string
          incumbent_name?: string | null
          last_addenda_checked_at?: string | null
          last_verified_at?: string | null
          lead_id?: string | null
          lead_source_id?: string | null
          matched_organization_id?: string | null
          next_action?: string | null
          next_action_due_at?: string | null
          no_bid_reason?: string | null
          notes?: string | null
          opportunity_id?: string | null
          owner_user_id?: string | null
          previous_award_value?: number | null
          published_date?: string | null
          raw_payload?: Json | null
          region?: string | null
          registration_required?: boolean
          response_mode?: string | null
          source: string
          source_url?: string | null
          status?: Database["public"]["Enums"]["tender_record_status"]
          submission_confirmed_at?: string | null
          submission_method?: string | null
          submission_receipt_url?: string | null
          submission_reference?: string | null
          title: string
          updated_at?: string
          vendor_prerequisite_status?: string | null
          watch_query?: string | null
          workspace_id: string
        }
        Update: {
          action_state?: string
          addenda_count?: number
          bid_decision_at?: string | null
          bid_decision_by?: string | null
          buyer_name?: string | null
          category?: string | null
          closing_date?: string | null
          contract_end_date?: string | null
          contract_start_date?: string | null
          created_at?: string
          currency?: string
          estimate_id?: string | null
          estimated_value?: number | null
          expected_rebid_date?: string | null
          external_id?: string
          fit_breakdown?: Json
          fit_note?: string | null
          fit_score?: number | null
          id?: string
          incumbent_name?: string | null
          last_addenda_checked_at?: string | null
          last_verified_at?: string | null
          lead_id?: string | null
          lead_source_id?: string | null
          matched_organization_id?: string | null
          next_action?: string | null
          next_action_due_at?: string | null
          no_bid_reason?: string | null
          notes?: string | null
          opportunity_id?: string | null
          owner_user_id?: string | null
          previous_award_value?: number | null
          published_date?: string | null
          raw_payload?: Json | null
          region?: string | null
          registration_required?: boolean
          response_mode?: string | null
          source?: string
          source_url?: string | null
          status?: Database["public"]["Enums"]["tender_record_status"]
          submission_confirmed_at?: string | null
          submission_method?: string | null
          submission_receipt_url?: string | null
          submission_reference?: string | null
          title?: string
          updated_at?: string
          vendor_prerequisite_status?: string | null
          watch_query?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tender_records_estimate_id_fkey"
            columns: ["estimate_id"]
            isOneToOne: false
            referencedRelation: "estimates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_records_lead_id_fkey"
            columns: ["lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_records_lead_source_id_fkey"
            columns: ["lead_source_id"]
            isOneToOne: false
            referencedRelation: "lead_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_records_matched_organization_id_fkey"
            columns: ["matched_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_records_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_records_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tender_requirements: {
        Row: {
          created_at: string
          description: string | null
          due_at: string | null
          evidence_url: string | null
          id: string
          mandatory: boolean
          notes: string | null
          owner_user_id: string | null
          requirement_type: string
          status: string
          tender_record_id: string
          title: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          due_at?: string | null
          evidence_url?: string | null
          id?: string
          mandatory?: boolean
          notes?: string | null
          owner_user_id?: string | null
          requirement_type?: string
          status?: string
          tender_record_id: string
          title: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          description?: string | null
          due_at?: string | null
          evidence_url?: string | null
          id?: string
          mandatory?: boolean
          notes?: string | null
          owner_user_id?: string | null
          requirement_type?: string
          status?: string
          tender_record_id?: string
          title?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tender_requirements_tender_record_id_fkey"
            columns: ["tender_record_id"]
            isOneToOne: false
            referencedRelation: "tender_records"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_requirements_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tender_sources: {
        Row: {
          created_at: string
          display_name: string
          enabled: boolean
          id: string
          ingestion_mode: string
          last_error: string | null
          last_run_at: string | null
          last_success_at: string | null
          source_key: string
          source_url: string | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          display_name: string
          enabled?: boolean
          id?: string
          ingestion_mode?: string
          last_error?: string | null
          last_run_at?: string | null
          last_success_at?: string | null
          source_key: string
          source_url?: string | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          display_name?: string
          enabled?: boolean
          id?: string
          ingestion_mode?: string
          last_error?: string | null
          last_run_at?: string | null
          last_success_at?: string | null
          source_key?: string
          source_url?: string | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tender_sources_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      tender_stage_history: {
        Row: {
          changed_by: string | null
          created_at: string
          from_stage: string | null
          id: string
          note: string | null
          tender_record_id: string
          to_stage: string
          workspace_id: string
        }
        Insert: {
          changed_by?: string | null
          created_at?: string
          from_stage?: string | null
          id?: string
          note?: string | null
          tender_record_id: string
          to_stage: string
          workspace_id: string
        }
        Update: {
          changed_by?: string | null
          created_at?: string
          from_stage?: string | null
          id?: string
          note?: string | null
          tender_record_id?: string
          to_stage?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tender_stage_history_tender_record_id_fkey"
            columns: ["tender_record_id"]
            isOneToOne: false
            referencedRelation: "tender_records"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tender_stage_history_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      time_entries: {
        Row: {
          approved: boolean
          cost_rate: number
          created_at: string
          employee_id: string
          ended_at: string | null
          hours: number
          id: string
          started_at: string
          total_cost: number
          work_order_id: string | null
          workspace_id: string
        }
        Insert: {
          approved?: boolean
          cost_rate: number
          created_at?: string
          employee_id: string
          ended_at?: string | null
          hours: number
          id?: string
          started_at: string
          total_cost: number
          work_order_id?: string | null
          workspace_id: string
        }
        Update: {
          approved?: boolean
          cost_rate?: number
          created_at?: string
          employee_id?: string
          ended_at?: string | null
          hours?: number
          id?: string
          started_at?: string
          total_cost?: number
          work_order_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "time_entries_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_entries_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      user_profiles: {
        Row: {
          active_workspace_id: string | null
          created_at: string
          display_name: string | null
          first_name: string | null
          id: string
          last_name: string | null
          phone: string | null
          updated_at: string
        }
        Insert: {
          active_workspace_id?: string | null
          created_at?: string
          display_name?: string | null
          first_name?: string | null
          id: string
          last_name?: string | null
          phone?: string | null
          updated_at?: string
        }
        Update: {
          active_workspace_id?: string | null
          created_at?: string
          display_name?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          phone?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_profiles_active_workspace_id_fkey"
            columns: ["active_workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      work_order_assignments: {
        Row: {
          assigned_at: string
          assignment_type: Database["public"]["Enums"]["assignment_type"]
          contractor_id: string | null
          crew_id: string | null
          employee_id: string | null
          equipment_id: string | null
          id: string
          status: Database["public"]["Enums"]["assignment_status"]
          unassigned_at: string | null
          work_order_id: string
          workspace_id: string
        }
        Insert: {
          assigned_at?: string
          assignment_type: Database["public"]["Enums"]["assignment_type"]
          contractor_id?: string | null
          crew_id?: string | null
          employee_id?: string | null
          equipment_id?: string | null
          id?: string
          status?: Database["public"]["Enums"]["assignment_status"]
          unassigned_at?: string | null
          work_order_id: string
          workspace_id: string
        }
        Update: {
          assigned_at?: string
          assignment_type?: Database["public"]["Enums"]["assignment_type"]
          contractor_id?: string | null
          crew_id?: string | null
          employee_id?: string | null
          equipment_id?: string | null
          id?: string
          status?: Database["public"]["Enums"]["assignment_status"]
          unassigned_at?: string | null
          work_order_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "work_order_assignments_contractor_id_fkey"
            columns: ["contractor_id"]
            isOneToOne: false
            referencedRelation: "contractors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_assignments_crew_id_fkey"
            columns: ["crew_id"]
            isOneToOne: false
            referencedRelation: "crews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_assignments_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_assignments_equipment_id_fkey"
            columns: ["equipment_id"]
            isOneToOne: false
            referencedRelation: "equipment"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_assignments_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_assignments_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_assignments_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      work_order_tasks: {
        Row: {
          completed_at: string | null
          completed_by: string | null
          description: string
          id: string
          notes: string | null
          required: boolean
          sequence: number
          status: string
          work_order_id: string
          workspace_id: string
        }
        Insert: {
          completed_at?: string | null
          completed_by?: string | null
          description: string
          id?: string
          notes?: string | null
          required?: boolean
          sequence?: number
          status?: string
          work_order_id: string
          workspace_id: string
        }
        Update: {
          completed_at?: string | null
          completed_by?: string | null
          description?: string
          id?: string
          notes?: string | null
          required?: boolean
          sequence?: number
          status?: string
          work_order_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "work_order_tasks_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_tasks_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_order_tasks_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      work_orders: {
        Row: {
          actual_duration_minutes: number | null
          cancelled_at: string | null
          completed_at: string | null
          contract_id: string | null
          contract_service_id: string | null
          created_at: string
          created_by: string | null
          description: string
          estimated_duration_minutes: number | null
          id: string
          priority: Database["public"]["Enums"]["work_priority"]
          property_id: string
          scheduled_end: string | null
          scheduled_start: string | null
          site_instructions: string | null
          source_type: Database["public"]["Enums"]["work_order_source"]
          status: Database["public"]["Enums"]["work_order_status"]
          updated_at: string
          work_order_number: string
          workspace_id: string
        }
        Insert: {
          actual_duration_minutes?: number | null
          cancelled_at?: string | null
          completed_at?: string | null
          contract_id?: string | null
          contract_service_id?: string | null
          created_at?: string
          created_by?: string | null
          description: string
          estimated_duration_minutes?: number | null
          id?: string
          priority?: Database["public"]["Enums"]["work_priority"]
          property_id: string
          scheduled_end?: string | null
          scheduled_start?: string | null
          site_instructions?: string | null
          source_type?: Database["public"]["Enums"]["work_order_source"]
          status?: Database["public"]["Enums"]["work_order_status"]
          updated_at?: string
          work_order_number: string
          workspace_id: string
        }
        Update: {
          actual_duration_minutes?: number | null
          cancelled_at?: string | null
          completed_at?: string | null
          contract_id?: string | null
          contract_service_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string
          estimated_duration_minutes?: number | null
          id?: string
          priority?: Database["public"]["Enums"]["work_priority"]
          property_id?: string
          scheduled_end?: string | null
          scheduled_start?: string | null
          site_instructions?: string | null
          source_type?: Database["public"]["Enums"]["work_order_source"]
          status?: Database["public"]["Enums"]["work_order_status"]
          updated_at?: string
          work_order_number?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "work_orders_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_contract_service_id_fkey"
            columns: ["contract_service_id"]
            isOneToOne: false
            referencedRelation: "contract_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "work_orders_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      work_visits: {
        Row: {
          completion_status: Database["public"]["Enums"]["work_order_status"]
          created_by: string | null
          ended_at: string | null
          id: string
          latitude: number | null
          longitude: number | null
          notes: string | null
          started_at: string
          work_order_id: string
          workspace_id: string
        }
        Insert: {
          completion_status?: Database["public"]["Enums"]["work_order_status"]
          created_by?: string | null
          ended_at?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          notes?: string | null
          started_at: string
          work_order_id: string
          workspace_id: string
        }
        Update: {
          completion_status?: Database["public"]["Enums"]["work_order_status"]
          created_by?: string | null
          ended_at?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          notes?: string | null
          started_at?: string
          work_order_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "work_visits_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_visits_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_visits_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspace_memberships: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["membership_role"]
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          user_id: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["membership_role"]
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          user_id: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["membership_role"]
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          user_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspace_memberships_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspace_ops_snapshots: {
        Row: {
          needs_dispatch_count: number
          open_issue_count: number
          open_task_count: number
          open_work_count: number
          overdue_task_count: number
          property_count: number
          renewal_count: number
          updated_at: string
          workspace_id: string
        }
        Insert: {
          needs_dispatch_count?: number
          open_issue_count?: number
          open_task_count?: number
          open_work_count?: number
          overdue_task_count?: number
          property_count?: number
          renewal_count?: number
          updated_at?: string
          workspace_id: string
        }
        Update: {
          needs_dispatch_count?: number
          open_issue_count?: number
          open_task_count?: number
          open_work_count?: number
          overdue_task_count?: number
          property_count?: number
          renewal_count?: number
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspace_ops_snapshots_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: true
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspaces: {
        Row: {
          created_at: string
          id: string
          name: string
          slug: string
          status: Database["public"]["Enums"]["workspace_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          slug: string
          status?: Database["public"]["Enums"]["workspace_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          slug?: string
          status?: Database["public"]["Enums"]["workspace_status"]
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      contract_renewal_queue: {
        Row: {
          billing_frequency: string | null
          contract_number: string | null
          contract_value: number | null
          created_at: string | null
          end_date: string | null
          id: string | null
          name: string | null
          opportunity_id: string | null
          organization_id: string | null
          property_id: string | null
          proposal_id: string | null
          renewal_type: string | null
          signed_document_id: string | null
          start_date: string | null
          status: Database["public"]["Enums"]["contract_status"] | null
          terminated_at: string | null
          updated_at: string | null
          workspace_id: string | null
        }
        Insert: {
          billing_frequency?: string | null
          contract_number?: string | null
          contract_value?: number | null
          created_at?: string | null
          end_date?: string | null
          id?: string | null
          name?: string | null
          opportunity_id?: string | null
          organization_id?: string | null
          property_id?: string | null
          proposal_id?: string | null
          renewal_type?: string | null
          signed_document_id?: string | null
          start_date?: string | null
          status?: Database["public"]["Enums"]["contract_status"] | null
          terminated_at?: string | null
          updated_at?: string | null
          workspace_id?: string | null
        }
        Update: {
          billing_frequency?: string | null
          contract_number?: string | null
          contract_value?: number | null
          created_at?: string | null
          end_date?: string | null
          id?: string | null
          name?: string | null
          opportunity_id?: string | null
          organization_id?: string | null
          property_id?: string | null
          proposal_id?: string | null
          renewal_type?: string | null
          signed_document_id?: string | null
          start_date?: string | null
          status?: Database["public"]["Enums"]["contract_status"] | null
          terminated_at?: string | null
          updated_at?: string | null
          workspace_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "contracts_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "contracts_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_signed_document_id_fkey"
            columns: ["signed_document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contracts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      open_issue_queue: {
        Row: {
          assigned_to: string | null
          contract_id: string | null
          created_at: string | null
          customer_visible: boolean | null
          description: string | null
          due_at: string | null
          id: string | null
          issue_type: Database["public"]["Enums"]["issue_type"] | null
          property_id: string | null
          reported_at: string | null
          reported_by: string | null
          resolution_notes: string | null
          resolved_at: string | null
          severity: Database["public"]["Enums"]["issue_severity"] | null
          status: Database["public"]["Enums"]["issue_status"] | null
          title: string | null
          updated_at: string | null
          work_order_id: string | null
          workspace_id: string | null
        }
        Insert: {
          assigned_to?: string | null
          contract_id?: string | null
          created_at?: string | null
          customer_visible?: boolean | null
          description?: string | null
          due_at?: string | null
          id?: string | null
          issue_type?: Database["public"]["Enums"]["issue_type"] | null
          property_id?: string | null
          reported_at?: string | null
          reported_by?: string | null
          resolution_notes?: string | null
          resolved_at?: string | null
          severity?: Database["public"]["Enums"]["issue_severity"] | null
          status?: Database["public"]["Enums"]["issue_status"] | null
          title?: string | null
          updated_at?: string | null
          work_order_id?: string | null
          workspace_id?: string | null
        }
        Update: {
          assigned_to?: string | null
          contract_id?: string | null
          created_at?: string | null
          customer_visible?: boolean | null
          description?: string | null
          due_at?: string | null
          id?: string | null
          issue_type?: Database["public"]["Enums"]["issue_type"] | null
          property_id?: string | null
          reported_at?: string | null
          reported_by?: string | null
          resolution_notes?: string | null
          resolved_at?: string | null
          severity?: Database["public"]["Enums"]["issue_severity"] | null
          status?: Database["public"]["Enums"]["issue_status"] | null
          title?: string | null
          updated_at?: string | null
          work_order_id?: string | null
          workspace_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "issues_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "issues_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "open_work_exceptions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "issues_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      open_work_exceptions: {
        Row: {
          actual_duration_minutes: number | null
          cancelled_at: string | null
          completed_at: string | null
          contract_id: string | null
          contract_service_id: string | null
          created_at: string | null
          created_by: string | null
          description: string | null
          estimated_duration_minutes: number | null
          id: string | null
          priority: Database["public"]["Enums"]["work_priority"] | null
          property_id: string | null
          scheduled_end: string | null
          scheduled_start: string | null
          site_instructions: string | null
          source_type: Database["public"]["Enums"]["work_order_source"] | null
          status: Database["public"]["Enums"]["work_order_status"] | null
          updated_at: string | null
          work_order_number: string | null
          workspace_id: string | null
        }
        Insert: {
          actual_duration_minutes?: number | null
          cancelled_at?: string | null
          completed_at?: string | null
          contract_id?: string | null
          contract_service_id?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          estimated_duration_minutes?: number | null
          id?: string | null
          priority?: Database["public"]["Enums"]["work_priority"] | null
          property_id?: string | null
          scheduled_end?: string | null
          scheduled_start?: string | null
          site_instructions?: string | null
          source_type?: Database["public"]["Enums"]["work_order_source"] | null
          status?: Database["public"]["Enums"]["work_order_status"] | null
          updated_at?: string | null
          work_order_number?: string | null
          workspace_id?: string | null
        }
        Update: {
          actual_duration_minutes?: number | null
          cancelled_at?: string | null
          completed_at?: string | null
          contract_id?: string | null
          contract_service_id?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          estimated_duration_minutes?: number | null
          id?: string | null
          priority?: Database["public"]["Enums"]["work_priority"] | null
          property_id?: string | null
          scheduled_end?: string | null
          scheduled_start?: string | null
          site_instructions?: string | null
          source_type?: Database["public"]["Enums"]["work_order_source"] | null
          status?: Database["public"]["Enums"]["work_order_status"] | null
          updated_at?: string | null
          work_order_number?: string | null
          workspace_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "work_orders_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contract_renewal_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "contracts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_contract_service_id_fkey"
            columns: ["contract_service_id"]
            isOneToOne: false
            referencedRelation: "contract_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "property_360"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_orders_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "v_property_intelligence"
            referencedColumns: ["property_id"]
          },
          {
            foreignKeyName: "work_orders_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      property_360: {
        Row: {
          active_contracts: number | null
          address_line_1: string | null
          city: string | null
          customer_name: string | null
          id: string | null
          name: string | null
          open_issues: number | null
          open_work_orders: number | null
          postal_code: string | null
          province: string | null
          status: Database["public"]["Enums"]["property_status"] | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "properties_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_next_actions: {
        Row: {
          action_type: string | null
          detail: string | null
          due_at: string | null
          entity_id: string | null
          entity_table: string | null
          href: string | null
          priority_score: number | null
          title: string | null
          workspace_id: string | null
        }
        Relationships: []
      }
      v_outreach_execution_queue: {
        Row: {
          buildings_managed: number | null
          contact_confidence_score: number | null
          contact_display_name: string | null
          contact_email: string | null
          contact_id: string | null
          contact_job_title: string | null
          contact_phone: string | null
          converted_lead_id: string | null
          created_at: string | null
          doors_managed: number | null
          high_signal_property_count: number | null
          id: string | null
          last_touch_at: string | null
          latest_draft_body: string | null
          latest_draft_channel: string | null
          latest_draft_id: string | null
          latest_draft_sent_at: string | null
          latest_draft_state: string | null
          latest_draft_subject: string | null
          linked_property_count: number | null
          list_name: string | null
          nearest_deadline: string | null
          next_action: string | null
          next_action_due_at: string | null
          notes: string | null
          open_signal_count: number | null
          organization_address: string | null
          organization_display_name: string | null
          organization_email: string | null
          organization_id: string | null
          organization_phone: string | null
          organization_type:
            | Database["public"]["Enums"]["organization_type"]
            | null
          organization_website: string | null
          outreach_list_id: string | null
          outreach_readiness_score: number | null
          owner_user_id: string | null
          priority: Database["public"]["Enums"]["work_priority"] | null
          property_count: number | null
          recommended_action: string | null
          region: string | null
          score: number | null
          score_reason: string | null
          service_fit: string[] | null
          status: Database["public"]["Enums"]["outreach_target_status"] | null
          top_signal: string | null
          touch_count: number | null
          updated_at: string | null
          why_now: string | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "outreach_targets_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_converted_lead_id_fkey"
            columns: ["converted_lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_outreach_list_id_fkey"
            columns: ["outreach_list_id"]
            isOneToOne: false
            referencedRelation: "outreach_lists"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_outreach_target_queue: {
        Row: {
          buildings_managed: number | null
          contact_display_name: string | null
          contact_email: string | null
          contact_id: string | null
          contact_job_title: string | null
          contact_phone: string | null
          converted_lead_id: string | null
          created_at: string | null
          doors_managed: number | null
          id: string | null
          last_touch_at: string | null
          linked_property_count: number | null
          list_name: string | null
          next_action: string | null
          next_action_due_at: string | null
          notes: string | null
          organization_address: string | null
          organization_display_name: string | null
          organization_email: string | null
          organization_id: string | null
          organization_phone: string | null
          organization_type:
            | Database["public"]["Enums"]["organization_type"]
            | null
          organization_website: string | null
          outreach_list_id: string | null
          owner_user_id: string | null
          priority: Database["public"]["Enums"]["work_priority"] | null
          region: string | null
          score: number | null
          score_reason: string | null
          status: Database["public"]["Enums"]["outreach_target_status"] | null
          touch_count: number | null
          updated_at: string | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "outreach_targets_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_converted_lead_id_fkey"
            columns: ["converted_lead_id"]
            isOneToOne: false
            referencedRelation: "leads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_outreach_list_id_fkey"
            columns: ["outreach_list_id"]
            isOneToOne: false
            referencedRelation: "outreach_lists"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outreach_targets_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_property_intelligence: {
        Row: {
          access_complexity: string | null
          address_line_1: string | null
          address_line_2: string | null
          building_count: number | null
          capital_projects_signal: string | null
          city: string | null
          construction_year: number | null
          contact_count: number | null
          data_confidence: string | null
          estimated_sqft: number | null
          exterior_scope: string | null
          floor_count: number | null
          grounds_scope: string | null
          intelligence_score: number | null
          intelligence_summary: string | null
          janitorial_scope: string | null
          known_floor_count: number | null
          liability_signal: string | null
          lot_area_sqft: number | null
          management_organization_id: string | null
          name: string | null
          occupancy_signal: string | null
          owner_organization_id: string | null
          ownership_type: string | null
          parking_spaces: number | null
          permit_count: number | null
          postal_code: string | null
          primary_customer_organization_id: string | null
          primary_source_label: string | null
          primary_source_url: string | null
          procurement_signal: string | null
          property_class: string | null
          property_id: string | null
          property_type: string | null
          province: string | null
          recent_permit_count: number | null
          recent_permit_value: number | null
          seasonal_priority: string | null
          snow_scope: string | null
          status: Database["public"]["Enums"]["property_status"] | null
          unit_count: number | null
          vendor_signal: string | null
          verified_at: string | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "properties_management_organization_id_fkey"
            columns: ["management_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "properties_owner_organization_id_fkey"
            columns: ["owner_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "properties_primary_customer_organization_id_fkey"
            columns: ["primary_customer_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "properties_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      advance_estimate: {
        Args: {
          p_action: string
          p_estimate_id: string
          p_site_confirmed?: boolean
          p_site_notes?: string
        }
        Returns: undefined
      }
      approve_outreach_draft: { Args: { p_draft_id: string }; Returns: string }
      claim_outreach_target: { Args: { p_target_id: string }; Returns: string }
      classify_outreach_reply: {
        Args: {
          p_classification: string
          p_provider?: string
          p_provider_message_id?: string
          p_provider_thread_id?: string
          p_referred_contact?: string
          p_renewal_date?: string
          p_summary?: string
          p_target_id: string
        }
        Returns: string
      }
      complete_work_order_with_invoice: {
        Args: { p_notes?: string; p_work_order_id: string }
        Returns: string
      }
      compute_outreach_target_score: {
        Args: {
          p_buildings_managed: number
          p_doors_managed: number
          p_has_contact: boolean
          p_has_phone_or_email: boolean
          p_linked_property_count?: number
          p_same_primary_region: boolean
        }
        Returns: number
      }
      convert_estimate_to_contract: {
        Args: { p_estimate_id: string }
        Returns: string
      }
      convert_outreach_target_to_lead: {
        Args: { p_target_id: string }
        Returns: string
      }
      create_deck_estimate_draft: {
        Args: {
          p_items: Json
          p_organization_id: string
          p_property_id: string
          p_valid_until: string
          p_workspace_id: string
        }
        Returns: string
      }
      create_notification: {
        Args: {
          p_action_href?: string
          p_body?: string
          p_entity_id?: string
          p_entity_type?: string
          p_title: string
          p_user_id: string
          p_workspace_id: string
        }
        Returns: string
      }
      enroll_outreach_target: {
        Args: { p_sequence_id: string; p_target_id: string }
        Returns: string
      }
      ensure_cb_outreach_sequence: {
        Args: { p_workspace_id: string }
        Returns: string
      }
      ensure_default_pm_sequence: {
        Args: { p_workspace_id: string }
        Returns: string
      }
      generate_outreach_draft: {
        Args: { p_channel?: string; p_objective?: string; p_target_id: string }
        Returns: string
      }
      generate_work_orders_from_contract: {
        Args: { p_contract_id: string; p_days_ahead?: number }
        Returns: number
      }
      has_workspace_role: {
        Args: {
          p_roles: Database["public"]["Enums"]["membership_role"][]
          p_workspace_id: string
        }
        Returns: boolean
      }
      is_workspace_member: {
        Args: { p_workspace_id: string }
        Returns: boolean
      }
      log_bd_outcome: {
        Args: { p_outcome: string; p_target_id: string }
        Returns: string
      }
      log_outreach_touch: {
        Args: {
          p_channel: Database["public"]["Enums"]["outreach_touch_channel"]
          p_new_status?: Database["public"]["Enums"]["outreach_target_status"]
          p_next_action?: string
          p_next_action_due_at?: string
          p_notes?: string
          p_outcome?: string
          p_target_id: string
        }
        Returns: string
      }
      mark_outreach_draft_sent: {
        Args: {
          p_draft_id: string
          p_provider?: string
          p_provider_message_id?: string
          p_provider_thread_id?: string
        }
        Returns: string
      }
      next_actions: {
        Args: { p_limit?: number; p_workspace_id: string }
        Returns: {
          action_type: string
          detail: string
          due_at: string
          entity_id: string
          href: string
          priority_score: number
          title: string
          workspace_id: string
        }[]
      }
      process_due_sequence_steps: {
        Args: { p_limit?: number; p_workspace_id: string }
        Returns: number
      }
      refresh_outreach_target_score: {
        Args: { p_target_id: string }
        Returns: number
      }
      refresh_outreach_target_scores_for_list: {
        Args: { p_list_id: string }
        Returns: number
      }
      refresh_workspace_ops_snapshot: {
        Args: { p_workspace_id: string }
        Returns: {
          needs_dispatch_count: number
          open_issue_count: number
          open_task_count: number
          open_work_count: number
          overdue_task_count: number
          property_count: number
          renewal_count: number
          updated_at: string
          workspace_id: string
        }
        SetofOptions: {
          from: "*"
          to: "workspace_ops_snapshots"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      storage_workspace_id: { Args: { object_name: string }; Returns: string }
      target_is_reachable: { Args: { p_target_id: string }; Returns: boolean }
      update_deck_estimate_draft: {
        Args: {
          p_estimate_id: string
          p_items: Json
          p_property_id: string
          p_valid_until: string
        }
        Returns: undefined
      }
    }
    Enums: {
      activity_status: "planned" | "completed" | "cancelled"
      activity_type:
        | "call"
        | "email"
        | "meeting"
        | "site_visit"
        | "note"
        | "task"
        | "other"
      assignment_status:
        | "assigned"
        | "accepted"
        | "declined"
        | "completed"
        | "cancelled"
      assignment_type: "crew" | "employee" | "contractor" | "equipment"
      communication_direction: "inbound" | "outbound" | "internal"
      communication_type:
        | "email"
        | "call"
        | "sms"
        | "meeting"
        | "letter"
        | "other"
      contract_status:
        | "draft"
        | "pending_signature"
        | "active"
        | "suspended"
        | "expired"
        | "terminated"
        | "renewal_pending"
      crew_status: "active" | "inactive"
      document_type:
        | "contract"
        | "proposal"
        | "estimate"
        | "insurance"
        | "receipt"
        | "site_plan"
        | "report"
        | "other"
      employment_status: "active" | "inactive" | "terminated"
      employment_type: "employee" | "contractor"
      enrollment_status: "active" | "paused" | "completed" | "cancelled"
      equipment_status: "available" | "assigned" | "maintenance" | "retired"
      estimate_status:
        | "draft"
        | "sent"
        | "accepted"
        | "rejected"
        | "expired"
        | "superseded"
      expense_status: "draft" | "submitted" | "approved" | "rejected" | "paid"
      inspection_result: "pass" | "warning" | "fail" | "not_applicable"
      inspection_status: "scheduled" | "in_progress" | "completed" | "cancelled"
      invoice_status:
        | "draft"
        | "issued"
        | "partially_paid"
        | "paid"
        | "void"
        | "overdue"
      issue_severity: "low" | "medium" | "high" | "critical"
      issue_status: "open" | "in_progress" | "blocked" | "resolved" | "closed"
      issue_type:
        | "service_failure"
        | "quality"
        | "customer_complaint"
        | "damage"
        | "safety"
        | "equipment"
        | "access"
        | "weather"
        | "scope"
        | "billing"
        | "staffing"
        | "other"
      lead_channel:
        | "permit"
        | "referral"
        | "inbound"
        | "cold_outreach"
        | "other"
        | "tender"
        | "directory"
      lead_source_status: "active" | "paused" | "error"
      membership_role:
        | "owner"
        | "administrator"
        | "operations_manager"
        | "operations_supervisor"
        | "sales_manager"
        | "sales_rep"
        | "field_supervisor"
        | "field_worker"
        | "finance"
        | "read_only"
      notification_channel: "in_app" | "email" | "sms"
      notification_status: "pending" | "sent" | "read" | "dismissed" | "failed"
      opportunity_lost_reason_category:
        | "price"
        | "timing"
        | "competitor"
        | "no_budget"
        | "scope_mismatch"
        | "unresponsive"
        | "other"
      opportunity_stage:
        | "new"
        | "qualified"
        | "site_visit"
        | "estimating"
        | "proposal"
        | "negotiation"
        | "won"
        | "lost"
      opportunity_status: "open" | "won" | "lost" | "on_hold"
      organization_type:
        | "prospect"
        | "customer"
        | "property_manager"
        | "condo_corporation"
        | "owner"
        | "vendor"
        | "subcontractor"
        | "supplier"
        | "partner"
        | "other"
      outreach_target_status:
        | "queued"
        | "contacted"
        | "responded"
        | "converted"
        | "rejected"
        | "do_not_contact"
      outreach_touch_channel:
        | "call"
        | "email"
        | "sms"
        | "door_knock"
        | "mail"
        | "other"
      pricing_model:
        | "fixed"
        | "unit"
        | "hourly"
        | "event"
        | "seasonal"
        | "recurring"
        | "other"
      property_status: "prospect" | "active" | "inactive" | "archived"
      proposal_status:
        | "draft"
        | "sent"
        | "accepted"
        | "rejected"
        | "expired"
        | "superseded"
      record_status: "active" | "inactive" | "archived"
      schedule_type: "recurring" | "one_time" | "event_triggered"
      sequence_step_channel: "call" | "email" | "sms" | "task" | "wait"
      system_event_status:
        | "pending"
        | "processing"
        | "processed"
        | "failed"
        | "dead_letter"
      task_status: "open" | "in_progress" | "completed" | "cancelled"
      task_type:
        | "follow_up"
        | "renewal"
        | "operations"
        | "issue"
        | "inspection"
        | "billing"
        | "administrative"
        | "other"
      tender_record_status:
        | "new"
        | "reviewing"
        | "pursuing"
        | "submitted"
        | "won"
        | "lost"
        | "not_pursuing"
        | "expired"
      unit_type:
        | "flat"
        | "hour"
        | "visit"
        | "square_foot"
        | "linear_foot"
        | "each"
        | "season"
        | "event"
        | "other"
      work_order_source:
        | "contract_schedule"
        | "manual"
        | "issue"
        | "emergency"
        | "estimate"
        | "other"
      work_order_status:
        | "draft"
        | "scheduled"
        | "assigned"
        | "en_route"
        | "in_progress"
        | "paused"
        | "completed"
        | "needs_review"
        | "approved"
        | "cancelled"
      work_priority: "low" | "normal" | "high" | "urgent" | "emergency"
      workspace_status: "active" | "suspended" | "archived"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      activity_status: ["planned", "completed", "cancelled"],
      activity_type: [
        "call",
        "email",
        "meeting",
        "site_visit",
        "note",
        "task",
        "other",
      ],
      assignment_status: [
        "assigned",
        "accepted",
        "declined",
        "completed",
        "cancelled",
      ],
      assignment_type: ["crew", "employee", "contractor", "equipment"],
      communication_direction: ["inbound", "outbound", "internal"],
      communication_type: [
        "email",
        "call",
        "sms",
        "meeting",
        "letter",
        "other",
      ],
      contract_status: [
        "draft",
        "pending_signature",
        "active",
        "suspended",
        "expired",
        "terminated",
        "renewal_pending",
      ],
      crew_status: ["active", "inactive"],
      document_type: [
        "contract",
        "proposal",
        "estimate",
        "insurance",
        "receipt",
        "site_plan",
        "report",
        "other",
      ],
      employment_status: ["active", "inactive", "terminated"],
      employment_type: ["employee", "contractor"],
      enrollment_status: ["active", "paused", "completed", "cancelled"],
      equipment_status: ["available", "assigned", "maintenance", "retired"],
      estimate_status: [
        "draft",
        "sent",
        "accepted",
        "rejected",
        "expired",
        "superseded",
      ],
      expense_status: ["draft", "submitted", "approved", "rejected", "paid"],
      inspection_result: ["pass", "warning", "fail", "not_applicable"],
      inspection_status: ["scheduled", "in_progress", "completed", "cancelled"],
      invoice_status: [
        "draft",
        "issued",
        "partially_paid",
        "paid",
        "void",
        "overdue",
      ],
      issue_severity: ["low", "medium", "high", "critical"],
      issue_status: ["open", "in_progress", "blocked", "resolved", "closed"],
      issue_type: [
        "service_failure",
        "quality",
        "customer_complaint",
        "damage",
        "safety",
        "equipment",
        "access",
        "weather",
        "scope",
        "billing",
        "staffing",
        "other",
      ],
      lead_channel: [
        "permit",
        "referral",
        "inbound",
        "cold_outreach",
        "other",
        "tender",
        "directory",
      ],
      lead_source_status: ["active", "paused", "error"],
      membership_role: [
        "owner",
        "administrator",
        "operations_manager",
        "operations_supervisor",
        "sales_manager",
        "sales_rep",
        "field_supervisor",
        "field_worker",
        "finance",
        "read_only",
      ],
      notification_channel: ["in_app", "email", "sms"],
      notification_status: ["pending", "sent", "read", "dismissed", "failed"],
      opportunity_lost_reason_category: [
        "price",
        "timing",
        "competitor",
        "no_budget",
        "scope_mismatch",
        "unresponsive",
        "other",
      ],
      opportunity_stage: [
        "new",
        "qualified",
        "site_visit",
        "estimating",
        "proposal",
        "negotiation",
        "won",
        "lost",
      ],
      opportunity_status: ["open", "won", "lost", "on_hold"],
      organization_type: [
        "prospect",
        "customer",
        "property_manager",
        "condo_corporation",
        "owner",
        "vendor",
        "subcontractor",
        "supplier",
        "partner",
        "other",
      ],
      outreach_target_status: [
        "queued",
        "contacted",
        "responded",
        "converted",
        "rejected",
        "do_not_contact",
      ],
      outreach_touch_channel: [
        "call",
        "email",
        "sms",
        "door_knock",
        "mail",
        "other",
      ],
      pricing_model: [
        "fixed",
        "unit",
        "hourly",
        "event",
        "seasonal",
        "recurring",
        "other",
      ],
      property_status: ["prospect", "active", "inactive", "archived"],
      proposal_status: [
        "draft",
        "sent",
        "accepted",
        "rejected",
        "expired",
        "superseded",
      ],
      record_status: ["active", "inactive", "archived"],
      schedule_type: ["recurring", "one_time", "event_triggered"],
      sequence_step_channel: ["call", "email", "sms", "task", "wait"],
      system_event_status: [
        "pending",
        "processing",
        "processed",
        "failed",
        "dead_letter",
      ],
      task_status: ["open", "in_progress", "completed", "cancelled"],
      task_type: [
        "follow_up",
        "renewal",
        "operations",
        "issue",
        "inspection",
        "billing",
        "administrative",
        "other",
      ],
      tender_record_status: [
        "new",
        "reviewing",
        "pursuing",
        "submitted",
        "won",
        "lost",
        "not_pursuing",
        "expired",
      ],
      unit_type: [
        "flat",
        "hour",
        "visit",
        "square_foot",
        "linear_foot",
        "each",
        "season",
        "event",
        "other",
      ],
      work_order_source: [
        "contract_schedule",
        "manual",
        "issue",
        "emergency",
        "estimate",
        "other",
      ],
      work_order_status: [
        "draft",
        "scheduled",
        "assigned",
        "en_route",
        "in_progress",
        "paused",
        "completed",
        "needs_review",
        "approved",
        "cancelled",
      ],
      work_priority: ["low", "normal", "high", "urgent", "emergency"],
      workspace_status: ["active", "suspended", "archived"],
    },
  },
} as const
