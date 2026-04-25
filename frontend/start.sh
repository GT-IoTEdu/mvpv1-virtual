#!/bin/bash
# .next/ already built into the image at docker build time.
exec npm run start -- -H 0.0.0.0 -p 3000
