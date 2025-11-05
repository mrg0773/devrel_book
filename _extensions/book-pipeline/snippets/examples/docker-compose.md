## Пример: Docker Compose для веб-приложения

```yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    depends_on:
      - api
  
  api:
    build: ./api
    environment:
      - DATABASE_URL=postgresql://db:5432/myapp
    ports:
      - "3000:3000"
    depends_on:
      - db
  
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: example
      POSTGRES_DB: myapp
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

**Запуск:**
```bash
docker-compose up -d
```

