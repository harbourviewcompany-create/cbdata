import { acceptInvite } from "../settings/actions";

export default async function InvitePage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const token = typeof params.token === "string" ? params.token : "";
  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">ACCESS</span>
          <h1>Accept invite</h1>
        </div>
      </header>
      <section className="panel">
        <form action={acceptInvite} className="form-grid">
          <input name="token" defaultValue={token} required placeholder="Invite token" />
          <button className="primary">Join workspace</button>
        </form>
      </section>
    </>
  );
}
