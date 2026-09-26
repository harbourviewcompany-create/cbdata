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
            foreignKeyName: "buildings_workspace_id_fkey"
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
          mobile: string | null
          notes: string | null
          phone: string | null
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
          mobile?: string | null
          notes?: string | null
          phone?: string | null
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
          mobile?: string | null
          notes?: string | null
          phone?: string | null
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
          created_at: string
          created_by: string | null
          estimate_number: string
          estimated_direct_cost: number
          estimated_gross_profit: number
          estimated_margin: number
          estimated_start_date: string | null
          id: string
          opportunity_id: string | null
          organization_id: string
          property_id: string | null
          status: Database["public"]["Enums"]["estimate_status"]
          subtotal: number
          tax: number
          total: number
          updated_at: string
          valid_until: string | null
          workspace_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          estimate_number: string
          estimated_direct_cost?: number
          estimated_gross_profit?: number
          estimated_margin?: number
          estimated_start_date?: string | null
          id?: string
          opportunity_id?: string | null
          organization_id: string
          property_id?: string | null
          status?: Database["public"]["Enums"]["estimate_status"]
          subtotal?: number
          tax?: number
          total?: number
          updated_at?: string
          valid_until?: string | null
          workspace_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          estimate_number?: string
          estimated_direct_cost?: number
          estimated_gross_profit?: number
          estimated_margin?: number
          estimated_start_date?: string | null
          id?: string
          opportunity_id?: string | null
          organization_id?: string
          property_id?: string | null
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
            foreignKeyName: "invoices_work_order_id_fkey"
            columns: ["work_order_id"]
            isOneToOne: false
            referencedRelation: "work_orders"
            referencedColumns: ["id"]
          },
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
          source: string | null
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
          source?: string | null
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
          source?: string | null
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
      opportunities: {
        Row: {
          closed_at: string | null
          created_at: string
          estimated_close_date: string | null
          estimated_start_date: string | null
          estimated_value: number
          id: string
          lost_reason: string | null
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
          lost_reason?: string | null
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
          lost_reason?: string | null
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
            foreignKeyName: "opportunities_workspace_id_fkey"
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
          created_at: string
          email: string | null
          id: string
          legal_name: string
          notes: string | null
          operating_name: string | null
          organization_type: Database["public"]["Enums"]["organization_type"]
          phone: string | null
          status: Database["public"]["Enums"]["record_status"]
          updated_at: string
          website: string | null
          workspace_id: string
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          email?: string | null
          id?: string
          legal_name: string
          notes?: string | null
          operating_name?: string | null
          organization_type: Database["public"]["Enums"]["organization_type"]
          phone?: string | null
          status?: Database["public"]["Enums"]["record_status"]
          updated_at?: string
          website?: string | null
          workspace_id: string
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          email?: string | null
          id?: string
          legal_name?: string
          notes?: string | null
          operating_name?: string | null
          organization_type?: Database["public"]["Enums"]["organization_type"]
          phone?: string | null
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
            foreignKeyName: "property_contacts_workspace_id_fkey"
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
      workspace_ops_snapshots: {
        Row: {
          overdue_task_count: number
          open_issue_count: number
          open_task_count: number
          open_work_count: number
          property_count: number
          needs_dispatch_count: number
          renewal_count: number
          updated_at: string
          workspace_id: string
        }
        Insert: {
          overdue_task_count?: number
          open_issue_count?: number
          open_task_count?: number
          open_work_count?: number
          property_count?: number
          needs_dispatch_count?: number
          renewal_count?: number
          updated_at?: string
          workspace_id: string
        }
        Update: {
          overdue_task_count?: number
          open_issue_count?: number
          open_task_count?: number
          open_work_count?: number
          property_count?: number
          needs_dispatch_count?: number
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
    }
    Functions: {
      complete_work_order_with_invoice: {
        Args: {
          p_notes?: string | null
          p_work_order_id: string
        }
        Returns: string
      }
      generate_work_orders_from_contract: {
        Args: {
          p_contract_id: string
          p_days_ahead?: number
        }
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
      next_actions: {
        Args: {
          p_limit?: number
          p_workspace_id: string
        }
        Returns: {
          action_type: string
          detail: string | null
          due_at: string | null
          entity_id: string
          href: string
          priority_score: number
          title: string
          workspace_id: string
        }[]
      }
      refresh_workspace_ops_snapshot: {
        Args: { p_workspace_id: string }
        Returns: {
          overdue_task_count: number
          open_issue_count: number
          open_task_count: number
          open_work_count: number
          property_count: number
          needs_dispatch_count: number
          renewal_count: number
          updated_at: string
          workspace_id: string
        }
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
