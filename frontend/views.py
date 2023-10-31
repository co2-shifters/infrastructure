import requests
from django.shortcuts import render
from django.http import HttpResponseRedirect
from .forms import InputForm


def index(request):
    if request.method == 'POST':
        form = InputForm(request.POST)
        if form.is_valid():
            input1 = form.cleaned_data['input1']
            input2 = form.cleaned_data['input2']
            input3 = form.cleaned_data['input3']
            url = f'https://abc.com?input1={input1}&input2={input2}&input3={input3}'
            response = requests.get(url)
            return render(request, 'response.html', {'response': response.text})
    else:
        form = InputForm()
    return render(request, 'index.html', {'form': form})


def response(request):
    return render(request, 'response.html', {'response': ''})