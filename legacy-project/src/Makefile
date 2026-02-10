.PHONY: init run test

init:
	@echo "Initializing database..."
	@cd .. && . venv/bin/activate && cd src/backend && python -c "from app import init_db; init_db()"

run:
	@echo "Starting Flask application..."
	@cd .. && . venv/bin/activate && cd src/backend && python app.py

test: 
	@echo "Running tests..."
	@cd .. && . venv/bin/activate && cd src/backend && python app_tests.py