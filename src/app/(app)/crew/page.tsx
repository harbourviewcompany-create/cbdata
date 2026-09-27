import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { addCrewMember, createCrew, createEmployee } from "./actions";

export default async function CrewPage() {
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();
  const [{ data: people }, { data: crews }, { data: members }, { data: gear }] =
    await Promise.all([
      s
        .from("employees")
        .select(
          "id,first_name,last_name,employment_status,employment_type,email,phone",
        )
        .eq("workspace_id", ctx.workspaceId)
        .order("last_name"),
      s
        .from("crews")
        .select("id,name,status,crew_type,supervisor_employee_id")
        .eq("workspace_id", ctx.workspaceId)
        .order("name"),
      s
        .from("crew_members")
        .select("id,crew_id,employee_id,start_date,end_date")
        .eq("workspace_id", ctx.workspaceId),
      s
        .from("equipment")
        .select("id,name,asset_number,equipment_type,status")
        .eq("workspace_id", ctx.workspaceId)
        .order("name")
        .limit(100),
    ]);

  const nameOf = (id: string) => {
    const p = people?.find((x) => x.id === id);
    return p ? `${p.first_name} ${p.last_name}` : "—";
  };

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">OPERATIONS</span>
          <h1>Crew</h1>
          <p className="muted">People, crews, and equipment available to dispatch.</p>
        </div>
      </header>

      <section className="table-panel">
        <h2>Add person</h2>
        <form action={createEmployee} className="form-grid">
          <input name="first_name" required placeholder="First name" />
          <input name="last_name" required placeholder="Last name" />
          <input name="email" type="email" placeholder="Email" />
          <input name="phone" placeholder="Phone" />
          <select name="employment_type" defaultValue="employee">
            <option value="employee">Employee</option>
            <option value="contractor">Contractor</option>
          </select>
          <input name="hire_date" type="date" />
          <button type="submit">Add</button>
        </form>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>People</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Status</th>
                <th>Contact</th>
              </tr>
            </thead>
            <tbody>
              {(people ?? []).map((p) => (
                <tr key={p.id}>
                  <td>
                    {p.first_name} {p.last_name}
                  </td>
                  <td>{p.employment_type}</td>
                  <td>{p.employment_status}</td>
                  <td>{p.phone ?? p.email ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>Create crew</h2>
        <form action={createCrew} className="form-grid">
          <input name="name" required placeholder="Crew name" />
          <input name="crew_type" placeholder="Type (snow, landscape…)" />
          <select name="supervisor_employee_id">
            <option value="">Supervisor</option>
            {(people ?? []).map((p) => (
              <option key={p.id} value={p.id}>
                {p.first_name} {p.last_name}
              </option>
            ))}
          </select>
          <button type="submit">Create crew</button>
        </form>
      </section>

      {(crews ?? []).map((c) => (
        <section key={c.id} className="table-panel" style={{ marginTop: 14 }}>
          <h2>
            {c.name}{" "}
            <span className="muted">
              {c.status}
              {c.crew_type ? ` · ${c.crew_type}` : ""}
            </span>
          </h2>
          <p className="muted">Supervisor: {c.supervisor_employee_id ? nameOf(c.supervisor_employee_id) : "—"}</p>
          <ul className="queue-list">
            {(members ?? [])
              .filter((m) => m.crew_id === c.id && !m.end_date)
              .map((m) => (
                <li key={m.id}>
                  <strong>{nameOf(m.employee_id)}</strong>
                  <span className="muted">since {m.start_date}</span>
                </li>
              ))}
          </ul>
          <form action={addCrewMember} className="form-grid" style={{ marginTop: 10 }}>
            <input type="hidden" name="crew_id" value={c.id} />
            <select name="employee_id" required>
              <option value="">Add member</option>
              {(people ?? []).map((p) => (
                <option key={p.id} value={p.id}>
                  {p.first_name} {p.last_name}
                </option>
              ))}
            </select>
            <input name="start_date" type="date" />
            <button type="submit">Add to crew</button>
          </form>
        </section>
      ))}

      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>Equipment</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Asset</th>
                <th>Name</th>
                <th>Type</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {(gear ?? []).length ? (
                gear!.map((e) => (
                  <tr key={e.id}>
                    <td>{e.asset_number}</td>
                    <td>{e.name}</td>
                    <td>{e.equipment_type}</td>
                    <td>{e.status}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={4} className="muted">
                    No equipment on file.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
