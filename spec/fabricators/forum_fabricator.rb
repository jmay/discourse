Fabricator(:forum) do
  # user
  title { sequence(:title) { |i| "This is a test forum #{i}" } }
end
