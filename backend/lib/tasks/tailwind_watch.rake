namespace :tailwindcss do
  desc "Watch and compile Tailwind CSS continuously"
  task :watch do
    system("npx tailwindcss -i ./app/assets/tailwind/application.css -o ./app/assets/builds/tailwind.css --watch")
  end
end