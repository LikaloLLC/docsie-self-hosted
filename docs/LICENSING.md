# Self-hosted licensing

**Docsie Self-Hosted is free for up to 10 workspace users and 25 individual named
portal users, with unlimited public knowledge-base views. Commercial use is
included, with no time limit.**

Run it for personal projects, a small business or a team inside a large company.
The free tier is not a trial and does not expire after 30 days.

| Allowance per installation | Free tier |
| --- | --- |
| Named workspace users creating and managing content | Up to 10 |
| Individual named portal users accessing training and secure documentation | Up to 25 |
| Public knowledge-base views | Unlimited |
| Personal or commercial use | Included, no time limit |

A paid commercial license is required when either user allowance is exceeded.
Count each person once in each applicable allowance across the installation,
even across multiple workspaces or portals. Someone using both roles counts
toward both allowances. Portal users are individual people, not tenant
organizations or concurrent sessions. Anonymous public documentation viewers
consume neither allowance. Infrastructure, storage and inference costs are yours.

Docsie remains proprietary. Free use and public deployment tooling do not make
the application open source. See the [license grant and distribution notice](../LICENSE).
The free tier does not grant a right to resell Docsie or operate Docsie itself
as a hosted service for third parties.

## Access and upgrades

Follow [installation instructions](INSTALL_KUBERNETES.md) and
[public image availability](PUBLIC_IMAGES.md) for the current release. If a required
image still needs registry access, [contact Docsie](https://www.docsie.io/demo/).
That release-access requirement does not impose a time limit on the free license.

Contact Docsie when your installation needs more than 10 workspace users, more than 25 named portal users, or a
commercial support agreement. A paid license can cover the existing installation;
you do not need to move your content solely to change licensing tiers.

## Technical enforcement

The preview image does not include the new offline-license enforcement work.
The workspace-user and portal-user allowances above still apply. Obtain any required image credentials from
Docsie; do not enable enforcement settings or assume an activation command is
available until the supplied image documents that capability.

## Third-party search components

The vendored Elastic operator includes its upstream [Elastic License 2.0](../charts/prerequisites/eck-operator/LICENSE). Elastic container images retain their upstream licenses; the Docsie application license does not replace them.
