describe 'container list' do
  it 'lists containers' do 
    k = run("kontena container list")
    expect(k.out.match(/.*kontena-agent.*/)).to be_truthy
  end
end