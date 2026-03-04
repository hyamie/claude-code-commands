---
name: ship
description: Deploy to staging or production
---

# Ship

Deploy the project.

## Usage
```
/ship staging      # Deploy to staging (Builder)
/ship production   # Deploy to production (Deployer)
```

## Staging (Builder handles)

1. Run tests
2. Build project
3. Deploy to staging
4. Verify deployment
5. Report staging URL

## Production (Deployer handles)

1. Verify staging tested
2. Verify code reviewed
3. Ask for confirmation
4. Wait for explicit "yes"
5. Deploy
6. Run health checks
7. Report status

**Production always requires explicit confirmation.**
