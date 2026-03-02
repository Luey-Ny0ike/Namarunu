# frozen_string_literal: true

class StoresController < ApplicationController
  before_action :set_store, only: %i[show edit update destroy]

  def index
    @stores = Store.all
    respond_to do |format|
      format.html
      format.json do
        q = params[:q].to_s.strip
        stores = q.present? ? Store.where("name ILIKE ?", "%#{q}%").limit(10) : Store.none
        render json: stores.map { |s|
          { id: s.id, name: s.name, email_address: s.email_address, phone_number: s.phone_number, currency: s.currency }
        }
      end
    end
  end

  def show
  end

  def new
    @store = Store.new
  end

  def create
    @store = Store.new(store_params)
    if @store.save
      redirect_to @store
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @store.update(store_params)
      redirect_to @store
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @store.destroy
    redirect_to stores_path
  end

  private

  def set_store
    @store = Store.find(params[:id])
  end

  def store_params
    params.require(:store).permit(:name, :email_address, :phone_number, :currency)
  end
end
