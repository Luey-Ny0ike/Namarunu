# frozen_string_literal: true

module App
  class CustomerContactsController < App::BaseController
    before_action :set_customer
    before_action :set_contact, only: %i[update destroy]

    def create
      contact = @customer.contacts.build(contact_params)
      authorize contact, :create?

      if contact.save
        redirect_to app_customer_path(@customer), notice: "Contact added."
      else
        redirect_to app_customer_path(@customer), alert: "Unable to add contact: #{contact.errors.full_messages.to_sentence}"
      end
    end

    def update
      authorize @contact, :update?

      if @contact.update(contact_params)
        redirect_to app_customer_path(@customer), notice: "Contact updated."
      else
        redirect_to app_customer_path(@customer), alert: "Unable to update contact: #{@contact.errors.full_messages.to_sentence}"
      end
    end

    def destroy
      authorize @contact, :destroy?
      @contact.destroy!
      redirect_to app_customer_path(@customer), notice: "Contact removed."
    end

    private

    def set_customer
      @customer = policy_scope(Account).find(params[:customer_id])
      authorize @customer, :show?
    end

    def set_contact
      @contact = @customer.contacts.find(params[:id])
    end

    def contact_params
      params.require(:contact).permit(:name, :phone, :email, :role)
    end
  end
end
