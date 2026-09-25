import { login } from "./actions";

export default function LoginPage() {
  return (
    <main className="auth-shell">
      <section className="auth-card">
        <div className="eyebrow">CB CONTRACTING</div>
        <h1>CBData</h1>
        <p className="muted">Operations, sales, service delivery and financial control in one system.</p>
        <form action={login} className="stack">
          <label>Email<input name="email" type="email" autoComplete="email" required /></label>
          <label>Password<input name="password" type="password" autoComplete="current-password" required /></label>
          <button className="primary" type="submit">Sign in</button>
        </form>
      </section>
    </main>
  );
}